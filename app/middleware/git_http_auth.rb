# Rack middleware that sits in front of Grack.
# - Anonymous pull (git-upload-pack) is always allowed.
# - Push (git-receive-pack) requires HTTP Basic auth with Lore username + PAT.
# - Non-fast-forward pushes to main are delegated to Grack/git (git itself
#   rejects them if the receive.denyNonFastForwards config is set in the bare repo,
#   which we set at repo creation time). Post-push hook updates last_pushed_at.
require "base64"

class GitHttpAuth
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    path = request.path_info

    if push_request?(request)
      user = authenticate(env)
      unless user
        return [
          401,
          { "WWW-Authenticate" => 'Basic realm="Lore"', "Content-Type" => "text/plain" },
          [ "Unauthorized" ]
        ]
      end
      # Store the authenticated user for post-processing
      env["lore.user"] = user
    end

    status, headers, body = @app.call(env)

    # After a successful push, update last_pushed_at on the repo record
    if push_request?(request) && status == 200 && env["lore.user"]
      update_repo_metadata(path)
    end

    [status, headers, body]
  end

  private

  def push_request?(request)
    # git-receive-pack (push) requests
    request.post? && (
      request.path_info.end_with?("/git-receive-pack") ||
      request.params["service"] == "git-receive-pack"
    )
  end

  def authenticate(env)
    auth = env["HTTP_AUTHORIZATION"].to_s
    return nil unless auth.start_with?("Basic ")
    decoded = Base64.decode64(auth[6..]).force_encoding("UTF-8")
    username, pat = decoded.split(":", 2)
    return nil if username.blank? || pat.blank?
    user = User.find_by(username: username)
    return nil unless user&.authenticate_pat(pat)
    user
  end

  def update_repo_metadata(path)
    # path looks like /owner/repo.git/...
    # Strip leading slash and split
    parts = path.sub(%r{^/}, "").split("/")
    return if parts.length < 2
    owner = parts[0]
    repo_name = parts[1].sub(/\.git$/, "")
    repo = Repo.find_by(owner: owner, name: repo_name)
    repo&.update_column(:last_pushed_at, Time.current)
  rescue => e
    Rails.logger.error("GitHttpAuth: failed to update metadata: #{e.message}")
  end
end

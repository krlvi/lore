require "grack"

# Rack middleware that handles Git Smart HTTP under /git/:owner/:repo.git
# - Anonymous GET (clone/fetch) allowed for all repos
# - POST (push) requires Basic auth with a valid PAT
# - Non-fast-forward pushes to main are rejected by git itself (bare repo has no receive.denyNonFastForwards=true)
class GitHttpMiddleware
  PATH_REGEX = %r{\A/git/([a-z0-9\-_]+)/([a-z0-9\-_\.]+)\.git(/.*)?}

  def initialize(app)
    @app = app
    @repo_root = Rails.application.config.lore_repo_root
  end

  def call(env)
    path = env["PATH_INFO"]
    match = path.match(PATH_REGEX)

    unless match
      return @app.call(env)
    end

    owner = match[1]
    repo_name = match[2]
    rest = match[3] || "/"

    # Look up repo
    repo = Repo.find_by(owner: owner, name: repo_name)
    unless repo
      return [ 404, { "Content-Type" => "text/plain" }, [ "Repository not found\n" ] ]
    end

    # Enforce auth for push (POST)
    if env["REQUEST_METHOD"] == "POST"
      user = find_user_from_basic_auth(env)
      unless user
        return [
          401,
          {
            "Content-Type" => "text/plain",
            "WWW-Authenticate" => 'Basic realm="Lore"'
          },
          [ "Authentication required for push\n" ]
        ]
      end
      # Update last_pushed_at after successful push
      env["lore.push_user"] = user
      env["lore.repo"] = repo
    end

    # Rewrite PATH_INFO so Grack sees just the repo-relative path
    # Grack's root is the repo_root, so path becomes /owner/repo_name.git/...
    new_path_info = "/#{owner}/#{repo_name}.git#{rest}"
    new_env = env.merge(
      "PATH_INFO" => new_path_info,
      "SCRIPT_NAME" => "/git"
    )

    grack_app = Grack::App.new(root: @repo_root, allow_push: true, allow_pull: true)
    status, headers, body = grack_app.call(new_env)

    # After a successful push, update metadata
    if status == 200 && env["lore.repo"] && env["REQUEST_METHOD"] == "POST"
      begin
        env["lore.repo"].update_column(:last_pushed_at, Time.current)
      rescue => e
        Rails.logger.warn("GitHttpMiddleware: failed to update last_pushed_at: #{e.message}")
      end
    end

    [ status, headers, body ]
  end

  private

  def find_user_from_basic_auth(env)
    require "base64"
    auth_header = env["HTTP_AUTHORIZATION"] || ""
    return nil unless auth_header.start_with?("Basic ")
    decoded = Base64.decode64(auth_header.sub("Basic ", "")).force_encoding("UTF-8")
    username, token = decoded.split(":", 2)
    return nil if username.blank? || token.blank?
    user = User.find_by(username: username)
    return nil unless user&.authenticate_pat(token)
    user
  end
end

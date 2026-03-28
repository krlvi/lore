module LoreAuth
  extend ActiveSupport::Concern

  # Authenticate via Bearer PAT token.
  # Sets @current_user if authenticated.
  def authenticate_pat!
    @current_user = find_user_from_pat
    unless @current_user
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  def find_user_from_pat
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")
    token = header.sub("Bearer ", "").strip
    return nil if token.blank?
    find_user_by_token(token)
  end

  # Authenticate via HTTP Basic auth (for git transport).
  # Returns [user, nil] or [nil, error].
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

  private

  def find_user_by_token(token)
    # We have to check all users since we only store the digest.
    # For demo scale this is fine; production would use a token lookup table.
    User.find_each.find { |u| u.authenticate_pat(token) }
  end
end

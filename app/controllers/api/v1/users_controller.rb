module Api
  module V1
    class UsersController < ApplicationController
      skip_before_action :verify_authenticity_token

      # POST /api/v1/users
      # Register a new user. Returns the PAT once.
      def create
        # Accept username at top level or nested under user key
        username = params[:username].presence || params.dig(:user, :username)
        user = User.new(username: username)
        if user.save
          render json: {
            user: {
              username: user.username,
              created_at: user.created_at
            },
            pat: user.raw_pat
          }, status: :created
        elsif user.errors[:username].any? { |e| e.include?("taken") }
          render json: { error: "Username already taken" }, status: :conflict
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/users/:username
      def show
        user = User.find_by!(username: params[:username])
        render json: {
          username: user.username,
          created_at: user.created_at
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      end

      # GET /api/v1/users/:username/repos
      def repos
        user = User.find_by!(username: params[:username])
        repos = Repo.where(owner: user.username)
                    .order(Arel.sql("CASE WHEN last_pushed_at IS NULL THEN 1 ELSE 0 END, last_pushed_at DESC, created_at DESC"))
        render json: {
          repos: repos.map { |r| repo_json(r) }
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      end

      # GET /api/v1/whoami
      def whoami
        authenticate_pat!
        return unless @current_user
        render json: {
          username: @current_user.username,
          starred_count: @current_user.stars.count
        }
      end

      private

      def repo_json(repo)
        {
          owner: repo.owner,
          name: repo.name,
          description: repo.description,
          tags: repo.tags_array,
          stars: repo.stars_count,
          last_pushed_at: repo.last_pushed_at,
          clone_url: repo.clone_url,
          web_url: repo.web_url
        }
      end
    end
  end
end

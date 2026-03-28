module Api
  module V1
    class UsersController < ApplicationController
      skip_before_action :verify_authenticity_token

      # POST /api/v1/users
      # Register a new user. Returns the PAT once.
      def create
        user = User.new(user_params)
        if user.save
          render json: {
            id: user.id,
            username: user.username,
            email: user.email,
            token: user.raw_pat
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/users/:username
      def show
        user = User.find_by!(username: params[:username])
        repos = Repo.where(owner: user.username).order(stars_count: :desc, created_at: :desc)
        render json: {
          username: user.username,
          email: user.email,
          repos: repos.map { |r| repo_json(r) }
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      end

      # GET /api/v1/whoami
      def whoami
        authenticate_pat!
        return unless @current_user
        render json: { username: @current_user.username, email: @current_user.email }
      end

      private

      def user_params
        params.require(:user).permit(:username, :email)
      end

      def repo_json(repo)
        {
          id: repo.id,
          owner: repo.owner,
          name: repo.name,
          description: repo.description,
          tags: repo.tags_array,
          stars_count: repo.stars_count,
          last_pushed_at: repo.last_pushed_at,
          web_url: repo.web_url,
          clone_url: repo.clone_url
        }
      end
    end
  end
end

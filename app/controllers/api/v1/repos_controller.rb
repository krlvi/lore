module Api
  module V1
    class ReposController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_pat!, only: [ :create ]

      # GET /api/v1/repos/:owner/:name
      def show
        repo = Repo.find_by!(owner: params[:owner], name: params[:name])
        render json: repo_json(repo)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Repo not found" }, status: :not_found
      end

      # POST /api/v1/repos
      def create
        owner = @current_user.username
        name = params[:name].to_s.strip

        unless name.match?(/\A[a-z0-9][a-z0-9\-_\.]*\z/)
          return render json: { error: "Invalid repo name. Use lowercase letters, numbers, hyphens, underscores, dots." }, status: :unprocessable_entity
        end

        if Repo.exists?(owner: owner, name: name)
          return render json: { error: "Repo already exists" }, status: :conflict
        end

        disk_path = File.join(Rails.application.config.lore_repo_root, owner, "#{name}.git")

        tags = params[:tags]
        tags_str = case tags
        when Array then tags.join(",")
        when String then tags
        else ""
        end

        repo = Repo.new(
          owner: owner,
          name: name,
          description: params[:description].to_s.strip.presence,
          tags: tags_str,
          disk_path: disk_path
        )

        if repo.save
          repo.update_embedding!
          render json: repo_json(repo), status: :created
        else
          render json: { errors: repo.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/repos/search?q=...
      def search
        query = params[:q].to_s.strip
        limit = [ (params[:limit] || 20).to_i, 100 ].min

        results = Repo.search(query, limit: limit)

        render json: {
          query: query,
          results: results.map do |r|
            repo_json(r[:repo]).merge(similarity: r[:score].round(4))
          end
        }
      end

      private

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

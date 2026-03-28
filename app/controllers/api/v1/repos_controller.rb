module Api
  module V1
    class ReposController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_pat!, only: [ :create ]

      # GET /api/v1/repos/:owner/:name
      def show
        repo = Repo.find_by!(owner: params[:owner], name: params[:name])
        render json: { repo: repo_json(repo) }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Repo not found" }, status: :not_found
      end

      # POST /api/v1/repos
      def create
        owner = @current_user.username
        name = params[:name].to_s.strip

        unless name.match?(/\A[a-z][a-z0-9\-]*\z/)
          return render json: { error: "Invalid repo name. Use lowercase letters, numbers, and hyphens, starting with a letter." }, status: :unprocessable_entity
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
          description: params[:description].to_s.strip,
          tags: tags_str,
          disk_path: disk_path
        )

        if repo.save
          repo.update_embedding!
          render json: { repo: repo_json(repo) }, status: :created
        else
          render json: { errors: repo.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/repos/search?q=...
      def search
        query = params[:q].to_s.strip
        if query.blank?
          return render json: { error: "q parameter is required" }, status: :bad_request
        end

        limit = [ (params[:limit] || 10).to_i, 100 ].min
        results = Repo.search(query, limit: limit)

        render json: {
          query: query,
          repos: results.map do |r|
            repo_json(r[:repo]).merge(similarity_score: r[:score].round(4))
          end
        }
      end

      private

      def repo_json(repo)
        host = ENV["LORE_HOST"] || request_base_url
        {
          owner: repo.owner,
          name: repo.name,
          description: repo.description,
          tags: repo.tags_array,
          clone_url: repo.clone_url(base_url: host),
          web_url: repo.web_url(base_url: host),
          default_branch: "main",
          stars: repo.stars_count,
          created_at: repo.created_at,
          last_pushed_at: repo.last_pushed_at
        }
      end

      def request_base_url
        "#{request.protocol}#{request.host_with_port}"
      end
    end
  end
end

module Api
  module V1
    class StarsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_pat!

      # POST /api/v1/repos/:owner/:name/star
      def create
        repo = find_repo
        return unless repo

        star = Star.find_or_initialize_by(user: @current_user, repo: repo)
        if star.new_record?
          star.save!
          repo.reload
          render json: { starred: true, stars_count: repo.stars_count }, status: :created
        else
          render json: { starred: true, stars_count: repo.stars_count }
        end
      end

      # DELETE /api/v1/repos/:owner/:name/star
      def destroy
        repo = find_repo
        return unless repo

        star = Star.find_by(user: @current_user, repo: repo)
        if star
          star.destroy!
          repo.reload
        end
        render json: { starred: false, stars_count: repo.stars_count }
      end

      private

      def find_repo
        repo = Repo.find_by(owner: params[:owner], name: params[:name])
        unless repo
          render json: { error: "Repo not found" }, status: :not_found
          return nil
        end
        repo
      end
    end
  end
end

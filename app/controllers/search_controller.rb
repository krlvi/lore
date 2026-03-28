class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    if @query.present?
      results = Repo.search(@query, limit: 20)
      @results = results.map { |r| { repo: r[:repo], score: r[:score] } }
    else
      @results = []
    end
  end
end

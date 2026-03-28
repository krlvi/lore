class HomeController < ApplicationController
  def index
    @featured_repos = Repo.where("stars_count > 0").order(stars_count: :desc, last_pushed_at: :desc).limit(8)
    @total_repos = Repo.where("stars_count > 0").count
    @total_users = User.count
  end
end

class HomeController < ApplicationController
  def index
    @featured_repos = Repo.order(stars_count: :desc, last_pushed_at: :desc).limit(8)
    @total_repos = Repo.count
    @total_users = User.count
  end
end

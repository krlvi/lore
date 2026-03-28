class OwnersController < ApplicationController
  def show
    @username = params[:owner]
    @user = User.find_by(username: @username)
    @repos = Repo.where(owner: @username).order(last_pushed_at: :desc, created_at: :desc)
    render status: :not_found if @repos.empty? && @user.nil?
  end
end

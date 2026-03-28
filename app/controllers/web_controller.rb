class WebController < ApplicationController
  # Homepage
  def index
    @featured_repos = Repo.order(stars_count: :desc, last_pushed_at: :desc).limit(12)
    @total_repos = Repo.count
    @total_users = User.count
  end

  # Search page
  def search
    @query = params[:q].to_s.strip
    if @query.present?
      results = Repo.search(@query, limit: 20)
      @results = results.map { |r| { repo: r[:repo], score: r[:score] } }
    else
      @results = []
    end
  end

  # User profile page
  def user
    @user = User.find_by!(username: params[:username])
    @repos = Repo.where(owner: @user.username).order(stars_count: :desc, created_at: :desc)
  rescue ActiveRecord::RecordNotFound
    render file: "#{Rails.root}/public/404.html", status: :not_found
  end

  # Repo detail page
  def repo
    @repo = Repo.find_by!(owner: params[:owner], name: params[:name])
    @readme = read_repo_readme(@repo)
  rescue ActiveRecord::RecordNotFound
    render file: "#{Rails.root}/public/404.html", status: :not_found
  end

  def getting_started
    @content = File.read(Rails.root.join("getting-started.md")) rescue "# Getting Started\n\nDocumentation coming soon."
  end

  private

  def read_repo_readme(repo)
    return nil unless Dir.exist?(repo.disk_path)
    # Try to read README from bare repo
    content = `git --git-dir=#{Shellwords.escape(repo.disk_path)} show HEAD:README.md 2>/dev/null`.strip
    content.presence
  rescue
    nil
  end
end

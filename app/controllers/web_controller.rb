class WebController < ApplicationController
  # Homepage
  def index
    @featured_repos = Repo.where("stars_count > 0").order(stars_count: :desc, last_pushed_at: :desc).limit(12)
    @total_repos = Repo.where("stars_count > 0").count
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
    @base_url = request.base_url
    @readme = read_repo_readme(@repo)
    @commits = read_repo_commits(@repo)
  rescue ActiveRecord::RecordNotFound
    render file: "#{Rails.root}/public/404.html", status: :not_found
  end

  def getting_started
    @content = File.read(Rails.root.join("getting-started.md")) rescue "# Getting Started\n\nDocumentation coming soon."
  end

  private

  def read_repo_readme(repo)
    return nil unless Dir.exist?(repo.disk_path)
    content = `git --git-dir=#{Shellwords.escape(repo.disk_path)} show HEAD:README.md 2>/dev/null`.strip
    content.presence
  rescue
    nil
  end

  def read_repo_commits(repo)
    return [] unless Dir.exist?(repo.disk_path)
    output = `git --git-dir=#{Shellwords.escape(repo.disk_path)} log --pretty=format:"%h|%s|%an|%ar" -8 2>/dev/null`
    output.lines.map do |line|
      hash, subject, author, time = line.chomp.split("|", 4)
      { hash: hash, subject: subject, author: author, time: time }
    end
  rescue
    []
  end
end

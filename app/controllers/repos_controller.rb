class ReposController < ApplicationController
  def show
    @owner = params[:owner]
    @repo = Repo.find_by!(owner: @owner, name: params[:repo])
    @readme = fetch_readme(@repo)
    @commits = fetch_commits(@repo)
    @base_url = "#{request.protocol}#{request.host_with_port}"
  rescue ActiveRecord::RecordNotFound
    render status: :not_found, plain: "Repo not found"
  end

  private

  def fetch_readme(repo)
    return nil unless Dir.exist?(repo.disk_path)
    result = `git --git-dir=#{Shellwords.escape(repo.disk_path)} show HEAD:README.md 2>/dev/null`
    $?.success? ? result : nil
  rescue
    nil
  end

  def fetch_commits(repo)
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

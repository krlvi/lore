class ReposController < ApplicationController
  def show
    @owner = params[:owner]
    @repo = Repo.find_by!(owner: @owner, name: params[:repo])
    @readme = fetch_readme(@repo)
  rescue ActiveRecord::RecordNotFound
    render status: :not_found, plain: "Repo not found"
  end

  private

  def fetch_readme(repo)
    return nil unless Dir.exist?(repo.disk_path)
    # Try to read README.md from the bare repo
    result = `git --git-dir=#{Shellwords.escape(repo.disk_path)} show HEAD:README.md 2>/dev/null`
    $?.success? ? result : nil
  rescue
    nil
  end
end

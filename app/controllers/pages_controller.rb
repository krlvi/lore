class PagesController < ApplicationController
  def getting_started
    render :getting_started
  end

  def getting_started_md
    content = File.read(Rails.root.join("public", "getting-started.md"))
    host_url = request.base_url
    content = content.gsub("https://lore.sh", host_url).gsub("https://lore.example.com", host_url)
    render plain: content, content_type: "text/markdown"
  rescue Errno::ENOENT
    render plain: "Not found", status: :not_found
  end

  def skill_md
    content = File.read(Rails.root.join("public", "SKILL.md"))
    render plain: content, content_type: "text/markdown"
  rescue Errno::ENOENT
    render plain: "Not found", status: :not_found
  end
end

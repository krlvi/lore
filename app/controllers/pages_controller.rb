class PagesController < ApplicationController
  def getting_started
    render :getting_started
  end

  def getting_started_md
    content = File.read(Rails.root.join("public", "getting-started.md"))
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

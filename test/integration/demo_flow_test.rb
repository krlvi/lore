require "test_helper"

# End-to-end demo validation
class DemoFlowTest < ActionDispatch::IntegrationTest
  setup do
    @repo_root = Rails.application.config.lore_repo_root
    FileUtils.mkdir_p(@repo_root)
  end

  test "full demo loop: register, create repo, search, star" do
    # Step 1: Register
    post "/api/v1/users",
      params: { user: { username: "demo-agent", email: "demo@lore.test" } },
      as: :json
    assert_response :created
    data = json_response
    assert data["token"].present?, "token should be returned"
    assert_equal "demo-agent", data["username"]
    pat = data["token"]

    # Step 2: Create a repo
    post "/api/v1/repos",
      params: { name: "my-deploy-tool", description: "Sends Slack alerts on deploy", tags: ["slack", "deploy"] },
      headers: { "Authorization" => "Bearer #{pat}" },
      as: :json
    assert_response :created
    repo_data = json_response
    assert_equal "my-deploy-tool", repo_data["name"]
    assert_equal "demo-agent", repo_data["owner"]
    assert repo_data["clone_url"].include?("my-deploy-tool.git")
    assert repo_data["web_url"].present?

    # Step 3: Verify bare repo on disk
    disk_path = File.join(@repo_root, "demo-agent", "my-deploy-tool.git")
    assert Dir.exist?(disk_path)
    assert File.read(File.join(disk_path, "HEAD")).include?("main")

    # Step 4: Get via API
    get "/api/v1/repos/demo-agent/my-deploy-tool", as: :json
    assert_response :ok
    assert_equal "demo-agent", json_response["owner"]

    # Step 5: Star the repo
    post "/api/v1/repos/demo-agent/my-deploy-tool/star",
      headers: { "Authorization" => "Bearer #{pat}" }, as: :json
    assert_response :created
    assert json_response["starred"]
  end

  test "search returns slack-notify as top result for demo query" do
    unless Repo.exists?(owner: "lore-agent", name: "slack-notify")
      disk_path = File.join(@repo_root, "lore-agent", "slack-notify.git")
      User.find_or_create_by!(username: "lore-agent") { |u| u.email = "lore@agent.test" }
      repo = Repo.create!(
        owner: "lore-agent", name: "slack-notify",
        description: "Posts a message to a Slack webhook. Input: SLACK_WEBHOOK_URL, MESSAGE.",
        tags: "slack,webhook,notification,messaging",
        disk_path: disk_path, stars_count: 34
      )
      repo.update_embedding!
    end

    get "/api/v1/repos/search?q=send+slack+notification", as: :json
    assert_response :ok
    results = json_response["results"] || []
    assert results.any?, "Should return results"
    assert_equal "slack-notify", results.first["name"]
  end

  test "unauthenticated push is rejected" do
    disk_path = File.join(@repo_root, "test-owner", "test-push.git")
    FileUtils.mkdir_p(disk_path)
    system("git init --bare #{Shellwords.escape(disk_path)} -q 2>/dev/null")
    # Create a DB record so middleware can find it
    unless Repo.exists?(owner: "test-owner", name: "test-push")
      User.find_or_create_by!(username: "test-owner") { |u| u.email = "to@test.com" }
      Repo.create!(owner: "test-owner", name: "test-push", disk_path: disk_path)
    end

    post "/git/test-owner/test-push.git/git-receive-pack",
      headers: { "Content-Type" => "application/x-git-receive-pack-request" }
    assert_includes [ 401, 403, 404 ], response.status
  end
end

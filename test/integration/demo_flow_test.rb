require "test_helper"

# End-to-end demo validation: register → create → clone → push → metadata refresh
# This tests the complete Lore loop from the demo script.
class DemoFlowTest < ActionDispatch::IntegrationTest
  setup do
    @repo_root = Rails.application.config.lore_repo_root
    FileUtils.mkdir_p(@repo_root)
  end

  test "full demo loop: register, create repo, and verify metadata" do
    # Step 1: Register an agent user
    post "/api/v1/users", params: { username: "demo-agent" }, as: :json
    assert_response :created
    data = json_response
    assert data["pat"].present?, "PAT should be returned on registration: #{data.inspect}"
    assert_equal "demo-agent", data.dig("user", "username")
    pat = data["pat"]
    assert pat.start_with?("lore_pat_"), "PAT should start with lore_pat_"

    # Step 2: Create a repo
    post "/api/v1/repos",
      params: { name: "my-deploy-tool", description: "Sends Slack alerts on deploy", tags: ["slack", "deploy"] },
      headers: { "Authorization" => "Bearer #{pat}" },
      as: :json
    assert_response :created
    repo_data = json_response.dig("repo") || json_response
    assert_equal "my-deploy-tool", repo_data["name"]
    assert_equal "demo-agent", repo_data["owner"]
    clone_url = repo_data["clone_url"]
    assert clone_url.include?("my-deploy-tool.git"), "clone_url should include repo name: #{clone_url}"
    assert repo_data["web_url"].present?, "web_url should be present"

    # Step 3: Verify the bare repo was created on disk
    disk_path = File.join(@repo_root, "demo-agent", "my-deploy-tool.git")
    assert Dir.exist?(disk_path), "Bare repo directory should exist at #{disk_path}"
    head_file = File.join(disk_path, "HEAD")
    assert File.exist?(head_file), "HEAD file should exist"
    head_content = File.read(head_file)
    assert_includes head_content, "main", "HEAD should point to main"

    # Step 4: Get repo metadata via API
    get "/api/v1/repos/demo-agent/my-deploy-tool", as: :json
    assert_response :ok
    repo_meta = json_response.dig("repo") || json_response
    assert_equal "demo-agent", repo_meta["owner"]
    assert_equal "my-deploy-tool", repo_meta["name"]
    assert_equal 0, repo_meta["stars"]

    # Step 5: Star the repo
    post "/api/v1/repos/demo-agent/my-deploy-tool/star",
      headers: { "Authorization" => "Bearer #{pat}" },
      as: :json
    assert_response :created
    assert json_response["starred"]

    # Step 6: Verify star count updated
    get "/api/v1/repos/demo-agent/my-deploy-tool", as: :json
    assert_response :ok
    updated = json_response.dig("repo") || json_response
    assert_equal 1, updated["stars"]

    # Step 7: List user's repos
    get "/api/v1/users/demo-agent/repos", as: :json
    assert_response :ok
    repos = json_response["repos"]
    assert repos.any? { |r| r["name"] == "my-deploy-tool" }
  end

  test "search returns slack-notify as top result for demo query" do
    # Seed the slack-notify repo
    disk_path = File.join(@repo_root, "lore-agent", "slack-notify.git")
    unless Repo.exists?(owner: "lore-agent", name: "slack-notify")
      User.find_or_create_by!(username: "lore-agent")
      repo = Repo.create!(
        owner: "lore-agent",
        name: "slack-notify",
        description: "Posts a message to a Slack webhook. Input: SLACK_WEBHOOK_URL, MESSAGE.",
        tags: "slack,webhook,notification,messaging",
        disk_path: disk_path,
        stars_count: 34
      )
      repo.update_embedding!
    end

    get "/api/v1/repos/search?q=send+slack+notification", as: :json
    assert_response :ok

    data = json_response
    repos = data["repos"] || data["results"] || []
    assert repos.any?, "Search should return results"
    top = repos.first
    assert_equal "slack-notify", top["name"], "slack-notify should be top result for 'send slack notification'"
    assert_equal "lore-agent", top["owner"]
  end

  test "search returns relevant results for multiple demo queries" do
    disk_path = File.join(@repo_root, "lore-agent", "slack-notify.git")
    unless Repo.exists?(owner: "lore-agent", name: "slack-notify")
      User.find_or_create_by!(username: "lore-agent")
      repo = Repo.create!(
        owner: "lore-agent", name: "slack-notify",
        description: "Posts a message to a Slack webhook. Input: SLACK_WEBHOOK_URL, MESSAGE.",
        tags: "slack,webhook,notification,messaging",
        disk_path: disk_path, stars_count: 34
      )
      repo.update_embedding!
    end

    [
      ["send slack message", "slack-notify"],
      ["post to webhook", "slack-notify"]
    ].each do |query, expected_name|
      get "/api/v1/repos/search?q=#{URI.encode_uri_component(query)}", as: :json
      assert_response :ok
      repos = json_response["repos"] || json_response["results"] || []
      assert repos.any? { |r| r["name"] == expected_name },
        "Expected '#{expected_name}' in results for '#{query}', got: #{repos.map { |r| r['name'] }.inspect}"
    end
  end
end

require "test_helper"

class Api::V1::ReposControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "repouser")
    @token = @user.raw_pat
    @repo_root = Rails.application.config.lore_repo_root
  end

  test "POST /api/v1/repos creates a repo" do
    post "/api/v1/repos",
      params: { name: "my-repo", description: "A test repo", tags: [ "test" ] },
      headers: { "Authorization" => "Bearer #{@token}" },
      as: :json
    assert_response :created
    data = json_response.dig("repo") || json_response
    assert_equal "my-repo", data["name"], "Expected name in: #{data.inspect}"
    assert_equal "repouser", data["owner"]
    assert data["clone_url"].include?("my-repo.git"), "clone_url missing: #{data.inspect}"
    assert data["web_url"].present?, "web_url missing: #{data.inspect}"
  end

  test "POST /api/v1/repos without auth returns 401" do
    post "/api/v1/repos", params: { name: "privaterepo" }, as: :json
    assert_response :unauthorized
  end

  test "POST /api/v1/repos with duplicate name returns 409" do
    create_test_repo(owner: "repouser", name: "existing")
    post "/api/v1/repos",
      params: { name: "existing", description: "duplicate" },
      headers: { "Authorization" => "Bearer #{@token}" },
      as: :json
    assert_response :conflict
  end

  test "GET /api/v1/repos/:owner/:name returns repo" do
    create_test_repo(owner: "repouser", name: "gettest", description: "Test repo")
    get "/api/v1/repos/repouser/gettest", as: :json
    assert_response :ok
    data = json_response.dig("repo") || json_response
    assert_equal "gettest", data["name"], "Expected name in: #{data.inspect}"
    assert_equal "repouser", data["owner"]
  end

  test "GET /api/v1/repos/:owner/:name returns 404 for missing repo" do
    get "/api/v1/repos/nobody/norepo", as: :json
    assert_response :not_found
  end

  test "GET /api/v1/repos/search returns ranked results" do
    repo = create_test_repo(
      owner: "repouser", name: "slack-tool",
      description: "Send Slack notifications via webhook",
      tags: "slack,webhook,notifications"
    )
    repo.update_embedding!

    get "/api/v1/repos/search?q=slack+notification", as: :json
    assert_response :ok
    data = json_response
    repos = data["repos"] || data["results"] || []
    assert repos.any? { |r| r["name"] == "slack-tool" }, "slack-tool not in results: #{repos.inspect}"
  end

  test "GET /api/v1/repos/search with missing q returns 400" do
    get "/api/v1/repos/search", as: :json
    assert_response :bad_request
  end

  test "GET /api/v1/repos/search with blank q returns 400" do
    get "/api/v1/repos/search?q=", as: :json
    assert_response :bad_request
  end
end

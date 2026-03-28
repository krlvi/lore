require "test_helper"

class Api::V1::ReposControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "repouser", email: "repouser@example.com")
    @token = @user.raw_pat
    @repo_root = Rails.application.config.lore_repo_root
  end

  test "POST /api/v1/repos creates a repo" do
    post "/api/v1/repos",
      params: { name: "myrepo", description: "A test repo", tags: [ "test" ] },
      headers: { "Authorization" => "Bearer #{@token}" },
      as: :json
    assert_response :created
    data = json_response
    assert_equal "myrepo", data["name"]
    assert_equal "repouser", data["owner"]
    assert data["clone_url"].include?("myrepo.git")
    assert data["web_url"].present?
  end

  test "POST /api/v1/repos without auth returns 401" do
    post "/api/v1/repos", params: { name: "privaterepo" }, as: :json
    assert_response :unauthorized
  end

  test "GET /api/v1/repos/:owner/:name returns repo" do
    disk_path = File.join(@repo_root, "repouser", "gettest.git")
    Repo.create!(owner: "repouser", name: "gettest", disk_path: disk_path)
    get "/api/v1/repos/repouser/gettest", as: :json
    assert_response :ok
    assert_equal "gettest", json_response["name"]
  end

  test "GET /api/v1/repos/search returns ranked results" do
    disk_path = File.join(@repo_root, "repouser", "slack-tool.git")
    repo = Repo.create!(
      owner: "repouser", name: "slack-tool",
      description: "Send Slack notifications", tags: "slack,webhook",
      disk_path: disk_path
    )
    repo.update_embedding!

    get "/api/v1/repos/search?q=slack+notification", as: :json
    assert_response :ok
    results = json_response["results"]
    assert results.any? { |r| r["name"] == "slack-tool" }
  end

  test "GET /api/v1/repos/search with no query returns repos" do
    get "/api/v1/repos/search?q=", as: :json
    assert_response :ok
    assert json_response.key?("results")
  end
end

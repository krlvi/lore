require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  test "POST /api/v1/users creates user and returns token" do
    post "/api/v1/users", params: { username: "alice" }, as: :json
    assert_response :created
    data = json_response
    assert data["pat"].present?, "Expected pat in response: #{data.inspect}"
    assert_equal "alice", data.dig("user", "username")
  end

  test "POST /api/v1/users with duplicate username returns 409" do
    User.create!(username: "bob")
    post "/api/v1/users", params: { username: "bob" }, as: :json
    assert_response :conflict
  end

  test "POST /api/v1/users with invalid username returns 422" do
    post "/api/v1/users", params: { username: "BadName!" }, as: :json
    assert_response :unprocessable_entity
  end

  test "GET /api/v1/users/:username returns user" do
    User.create!(username: "carol")
    get "/api/v1/users/carol", as: :json
    assert_response :ok
    assert_equal "carol", json_response["username"]
  end

  test "GET /api/v1/users/:username/repos returns repos" do
    User.create!(username: "carol2")
    create_test_repo(owner: "carol2", name: "my-tool")
    get "/api/v1/users/carol2/repos", as: :json
    assert_response :ok
    assert json_response.key?("repos"), "Expected repos key: #{json_response.inspect}"
  end

  test "GET /api/v1/whoami returns current user" do
    user = User.create!(username: "dave")
    get "/api/v1/whoami", headers: { "Authorization" => "Bearer #{user.raw_pat}" }, as: :json
    assert_response :ok
    assert_equal "dave", json_response["username"]
  end

  test "GET /api/v1/whoami without token returns 401" do
    get "/api/v1/whoami", as: :json
    assert_response :unauthorized
  end
end

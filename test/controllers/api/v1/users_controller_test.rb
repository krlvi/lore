require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  test "POST /api/v1/users creates user and returns token" do
    post "/api/v1/users", params: { user: { username: "alice", email: "alice@example.com" } }, as: :json
    assert_response :created
    data = json_response
    assert data["token"].present?
    assert_equal "alice", data["username"]
  end

  test "POST /api/v1/users with duplicate username returns error" do
    User.create!(username: "bob", email: "bob@example.com")
    post "/api/v1/users", params: { user: { username: "bob", email: "bob2@example.com" } }, as: :json
    assert_response :unprocessable_entity
  end

  test "GET /api/v1/users/:username returns user with repos" do
    user = User.create!(username: "carol", email: "carol@example.com")
    get "/api/v1/users/carol", as: :json
    assert_response :ok
    assert_equal "carol", json_response["username"]
    assert json_response.key?("repos")
  end

  test "GET /api/v1/whoami returns current user" do
    user = User.create!(username: "dave", email: "dave@example.com")
    get "/api/v1/whoami", headers: { "Authorization" => "Bearer #{user.raw_pat}" }, as: :json
    assert_response :ok
    assert_equal "dave", json_response["username"]
  end

  test "GET /api/v1/whoami without token returns 401" do
    get "/api/v1/whoami", as: :json
    assert_response :unauthorized
  end
end

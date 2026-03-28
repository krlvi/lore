require "test_helper"

class Api::V1::StarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "staruser", email: "staruser@example.com")
    @token = @user.raw_pat
    @repo_root = Rails.application.config.lore_repo_root
    disk_path = File.join(@repo_root, "staruser", "starrepo.git")
    @repo = Repo.create!(owner: "staruser", name: "starrepo", disk_path: disk_path)
  end

  test "POST star creates a star" do
    assert_difference "Star.count", 1 do
      post "/api/v1/repos/staruser/starrepo/star",
        headers: { "Authorization" => "Bearer #{@token}" },
        as: :json
    end
    assert_response :created
    assert json_response["starred"]
  end

  test "POST star is idempotent" do
    post "/api/v1/repos/staruser/starrepo/star",
      headers: { "Authorization" => "Bearer #{@token}" }, as: :json
    post "/api/v1/repos/staruser/starrepo/star",
      headers: { "Authorization" => "Bearer #{@token}" }, as: :json
    assert_response :ok
    assert_equal 1, Star.where(user: @user, repo: @repo).count
  end

  test "DELETE star removes a star" do
    Star.create!(user: @user, repo: @repo)
    @repo.update_column(:stars_count, 1)

    delete "/api/v1/repos/staruser/starrepo/star",
      headers: { "Authorization" => "Bearer #{@token}" },
      as: :json
    assert_response :ok
    assert_not json_response["starred"]
  end

  test "star without auth returns 401" do
    post "/api/v1/repos/staruser/starrepo/star", as: :json
    assert_response :unauthorized
  end
end

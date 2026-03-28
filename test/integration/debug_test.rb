require "test_helper"

class DebugTest < ActionDispatch::IntegrationTest
  test "registration returns pat" do
    post "/api/v1/users", params: { username: "alice-debug" }, as: :json
    puts "\nStatus: #{response.status}"
    puts "Body: #{response.body}"
    assert_response :created
    data = json_response
    assert data["pat"].present?, "Expected pat in: #{data.inspect}"
  end
end

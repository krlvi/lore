ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      # Ensure test repo root exists
      FileUtils.mkdir_p(Rails.application.config.lore_repo_root)
    end

    teardown do
      # Clean up test repos
      repo_root = Rails.application.config.lore_repo_root
      FileUtils.rm_rf(repo_root) if repo_root.include?("test_repos")
    end

    def json_response
      ::JSON.parse(response.body)
    end

    def auth_header(token)
      { "Authorization" => "Bearer #{token}" }
    end

    def create_test_user(username: "testuser")
      user = User.new(username: username)
      user.save!
      [user, user.raw_pat]
    end

    def create_test_repo(owner:, name:, description: nil, tags: nil)
      disk_path = File.join(Rails.application.config.lore_repo_root, owner, "#{name}.git")
      repo = Repo.create!(
        owner: owner,
        name: name,
        description: description,
        tags: tags,
        disk_path: disk_path
      )
      repo
    end
  end
end

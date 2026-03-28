ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Use transactional tests to automatically rollback DB changes after each test.
    self.use_transactional_tests = true

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

    def create_test_repo(owner:, name:, description: nil, tags: nil, stars_count: 1, featured: false)
      disk_path = File.join(Rails.application.config.lore_repo_root, owner, "#{name}.git")
      repo = Repo.create!(
        owner: owner,
        name: name,
        description: description,
        tags: tags,
        disk_path: disk_path,
        stars_count: stars_count,
        featured: featured
      )
      repo
    end
  end
end

# Ensure integration tests also clean up DB records after each test.
# ActionDispatch::IntegrationTest does not use transactions by default.
module IntegrationTestCleanup
  def teardown
    super
    Star.delete_all
    Repo.delete_all
    User.delete_all
    # Clean up test repos
    repo_root = Rails.application.config.lore_repo_root
    FileUtils.rm_rf(repo_root) if repo_root.include?("test_repos")
  end
end

ActionDispatch::IntegrationTest.prepend(IntegrationTestCleanup)

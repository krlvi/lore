require "test_helper"

class RepoTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "testuser", email: "test@example.com")
    @repo_root = Rails.application.config.lore_repo_root
  end

  test "creates repo with valid attributes" do
    disk_path = File.join(@repo_root, "testuser", "myrepo.git")
    repo = Repo.new(
      owner: "testuser",
      name: "myrepo",
      description: "A test repo",
      tags: "test,example",
      disk_path: disk_path
    )
    assert repo.save, repo.errors.full_messages.inspect
  end

  test "rejects invalid repo name" do
    disk_path = File.join(@repo_root, "testuser", "INVALID.git")
    repo = Repo.new(owner: "testuser", name: "INVALID NAME", disk_path: disk_path)
    assert_not repo.valid?
  end

  test "initializes bare git repo on disk" do
    disk_path = File.join(@repo_root, "testuser", "bare-test.git")
    FileUtils.rm_rf(disk_path)

    repo = Repo.create!(
      owner: "testuser",
      name: "bare-test",
      disk_path: disk_path
    )

    assert Dir.exist?(disk_path), "Bare repo directory should exist"
    assert File.exist?(File.join(disk_path, "HEAD")), "HEAD file should exist"
    head_content = File.read(File.join(disk_path, "HEAD"))
    assert_includes head_content, "main", "HEAD should point to main"
  end

  test "tags_array parses comma-separated tags" do
    repo = Repo.new(tags: "slack,webhook,notification")
    assert_equal %w[slack webhook notification], repo.tags_array
  end

  test "search returns results ranked by similarity" do
    disk_path1 = File.join(@repo_root, "testuser", "slack-tool.git")
    disk_path2 = File.join(@repo_root, "testuser", "postgres-tool.git")

    repo1 = Repo.create!(owner: "testuser", name: "slack-tool",
                 description: "Send Slack notifications via webhook",
                 tags: "slack,webhook", disk_path: disk_path1, stars_count: 5)
    repo2 = Repo.create!(owner: "testuser", name: "postgres-tool",
                 description: "Query PostgreSQL database",
                 tags: "postgres,sql", disk_path: disk_path2, stars_count: 3)

    repo1.update_embedding!
    repo2.update_embedding!

    results = Repo.search("slack notification")
    assert results.length > 0
    top = results.first[:repo]
    assert_equal "slack-tool", top.name, "slack-tool should rank higher for 'slack notification'"
  end

  test "web_url and clone_url are correct" do
    disk_path = File.join(@repo_root, "testuser", "url-test.git")
    repo = Repo.create!(owner: "testuser", name: "url-test", disk_path: disk_path)
    assert_includes repo.web_url, "/testuser/url-test"
    assert_includes repo.clone_url, "/git/testuser/url-test.git"
  end
end

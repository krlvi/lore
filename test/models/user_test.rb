require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "creates user with valid attributes" do
    user = User.new(username: "alice")
    assert user.save, "Should save valid user: #{user.errors.full_messages}"
    assert user.pat_digest.present?
    assert user.raw_pat.present?
    assert user.raw_pat.start_with?("lore_pat_")
  end

  test "rejects duplicate username" do
    User.create!(username: "bob")
    user2 = User.new(username: "bob")
    assert_not user2.valid?
    assert_includes user2.errors[:username], "has already been taken"
  end

  test "rejects invalid username format — uppercase" do
    user = User.new(username: "BobSmith")
    assert_not user.valid?
  end

  test "rejects invalid username format — starts with number" do
    user = User.new(username: "123bad")
    assert_not user.valid?
  end

  test "rejects invalid username format — spaces" do
    user = User.new(username: "bob smith")
    assert_not user.valid?
  end

  test "authenticates PAT correctly" do
    user = User.create!(username: "carol")
    token = user.raw_pat
    assert user.authenticate_pat(token)
    assert_not user.authenticate_pat("wrong_token")
  end
end

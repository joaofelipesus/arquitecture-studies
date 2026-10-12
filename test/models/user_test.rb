require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "is valid with a username and bio" do
    assert users(:alice).valid?
  end

  test "is valid without a bio" do
    assert User.new(username: "carol").valid?
  end

  test "is invalid without a username" do
    user = User.new(username: nil)

    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "is invalid with a blank username" do
    user = User.new(username: "   ")

    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "is invalid with a username that already exists" do
    user = User.new(username: users(:alice).username)

    assert_not user.valid?
    assert_includes user.errors[:username], "has already been taken"
  end

  test "strips surrounding whitespace from the username" do
    assert_equal "carol", User.new(username: "  carol ").username
  end

  test "treats a username with surrounding whitespace as taken" do
    user = User.new(username: " alice ")

    assert_not user.valid?
    assert_includes user.errors[:username], "has already been taken"
  end
end

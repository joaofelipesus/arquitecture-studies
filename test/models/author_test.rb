require "test_helper"

class AuthorTest < ActiveSupport::TestCase
  test "is valid with a name" do
    assert Author.new(name: "Isaac Asimov").valid?
  end

  test "is invalid without a name" do
    author = Author.new(name: " ")

    assert_not author.valid?
    assert_includes author.errors[:name], "can't be blank"
  end

  test "is invalid with a name that already exists" do
    author = Author.new(name: authors(:herbert).name)

    assert_not author.valid?
    assert_includes author.errors[:name], "has already been taken"
  end

  test "squishes whitespace in the name" do
    assert_equal "Isaac Asimov", Author.new(name: "  Isaac   Asimov ").name
  end

  test "has many books" do
    assert_equal [ books(:one) ], authors(:herbert).books
  end

  test "removes its book links when destroyed" do
    assert_difference("AuthorBook.count", -1) do
      authors(:herbert).destroy
    end
    assert Book.exists?(books(:one).id)
  end
end

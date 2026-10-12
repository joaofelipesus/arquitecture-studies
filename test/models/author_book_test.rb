require "test_helper"

class AuthorBookTest < ActiveSupport::TestCase
  test "is valid with an author and a book" do
    assert AuthorBook.new(author: authors(:herbert), book: books(:two)).valid?
  end

  test "is invalid without an author" do
    assert_not AuthorBook.new(book: books(:one)).valid?
  end

  test "is invalid without a book" do
    assert_not AuthorBook.new(author: authors(:herbert)).valid?
  end

  test "is invalid when linking the same author and book twice" do
    author_book = AuthorBook.new(author: authors(:herbert), book: books(:one))

    assert_not author_book.valid?
    assert_includes author_book.errors[:author_id], "has already been taken"
  end
end

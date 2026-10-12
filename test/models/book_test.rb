require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "is valid with all attributes" do
    assert books(:one).valid?
  end

  test "is valid with only a title" do
    assert Book.new(title: "Dune").valid?
  end

  test "is invalid without a title" do
    book = Book.new(title: nil)

    assert_not book.valid?
    assert_includes book.errors[:title], "can't be blank"
  end

  test "is invalid with a blank title" do
    book = Book.new(title: "   ")

    assert_not book.valid?
    assert_includes book.errors[:title], "can't be blank"
  end

  test "has many authors" do
    assert_equal [ authors(:herbert) ], books(:one).authors
  end

  test "author_name links an existing author" do
    book = Book.new(title: "Dune Messiah", author_name: "Frank Herbert")

    assert_no_difference("Author.count") { book.save! }
    assert_equal [ authors(:herbert) ], book.authors
  end

  test "author_name matches an existing author ignoring extra whitespace" do
    book = Book.new(title: "Dune Messiah", author_name: "  Frank   Herbert ")

    assert_no_difference("Author.count") { book.save! }
    assert_equal [ authors(:herbert) ], book.authors
  end

  test "author_name creates the author when it does not exist" do
    book = Book.new(title: "Foundation", author_name: "Isaac Asimov")

    assert_difference("Author.count", 1) { book.save! }
    assert_equal [ "Isaac Asimov" ], book.authors.map(&:name)
  end

  test "author_name does not create the author when the book is invalid" do
    book = Book.new(title: "", author_name: "Isaac Asimov")

    assert_no_difference(-> { Author.count } => 0, -> { AuthorBook.count } => 0) do
      assert_not book.save
    end
  end

  test "author_name is ignored when blank" do
    book = Book.new(title: "Anonymous", author_name: " ")

    assert book.save
    assert_empty book.authors
  end

  test "author_name does not link the same author twice" do
    book = Book.new(title: "Dune Messiah")
    book.author_name = "Frank Herbert"
    book.author_name = "Frank Herbert"

    assert_difference("AuthorBook.count", 1) { book.save! }
  end

  test "removes its author links but keeps the authors when destroyed" do
    assert_difference("AuthorBook.count", -1) do
      books(:one).destroy
    end
    assert Author.exists?(authors(:herbert).id)
  end
end

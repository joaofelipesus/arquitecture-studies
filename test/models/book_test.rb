require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "is valid with all attributes" do
    assert books(:one).valid?
  end

  test "is valid with only a title and total pages" do
    assert Book.new(title: "Dune", total_pages: 100).valid?
  end

  test "is invalid without a title" do
    book = Book.new(title: nil)

    assert_not book.valid?
    assert_includes book.errors[:title], "can't be blank"
  end

  test "is invalid with a blank title" do
    book = Book.new(title: "   ", total_pages: 100)

    assert_not book.valid?
    assert_includes book.errors[:title], "can't be blank"
  end

  test "is invalid without total pages" do
    book = Book.new(title: "Dune")

    assert_not book.valid?
    assert_includes book.errors[:total_pages], "can't be blank"
  end

  test "is invalid with zero total pages" do
    book = Book.new(title: "Dune", total_pages: 0)

    assert_not book.valid?
    assert_includes book.errors[:total_pages], "must be greater than 0"
  end

  test "is invalid with negative total pages" do
    book = Book.new(title: "Dune", total_pages: -10)

    assert_not book.valid?
    assert_includes book.errors[:total_pages], "must be greater than 0"
  end

  test "is invalid with fractional total pages" do
    book = Book.new(title: "Dune", total_pages: 12.5)

    assert_not book.valid?
    assert_includes book.errors[:total_pages], "must be an integer"
  end

  test "is invalid with non-numeric total pages" do
    book = Book.new(title: "Dune", total_pages: "many")

    assert_not book.valid?
    assert_includes book.errors[:total_pages], "is not a number"
  end

  test "has many authors" do
    assert_equal [ authors(:herbert) ], books(:one).authors
  end

  test "author_name links an existing author" do
    book = Book.new(title: "Dune Messiah", total_pages: 100, author_name: "Frank Herbert")

    assert_no_difference("Author.count") { book.save! }
    assert_equal [ authors(:herbert) ], book.authors
  end

  test "author_name matches an existing author ignoring extra whitespace" do
    book = Book.new(title: "Dune Messiah", total_pages: 100, author_name: "  Frank   Herbert ")

    assert_no_difference("Author.count") { book.save! }
    assert_equal [ authors(:herbert) ], book.authors
  end

  test "author_name creates the author when it does not exist" do
    book = Book.new(title: "Foundation", total_pages: 100, author_name: "Isaac Asimov")

    assert_difference("Author.count", 1) { book.save! }
    assert_equal [ "Isaac Asimov" ], book.authors.map(&:name)
  end

  test "author_name does not create the author when the book is invalid" do
    book = Book.new(title: "", total_pages: 100, author_name: "Isaac Asimov")

    assert_no_difference(-> { Author.count } => 0, -> { AuthorBook.count } => 0) do
      assert_not book.save
    end
  end

  test "author_name is ignored when blank" do
    book = Book.new(title: "Anonymous", total_pages: 100, author_name: " ")

    assert book.save
    assert_empty book.authors
  end

  test "author_name does not link the same author twice" do
    book = Book.new(title: "Dune Messiah", total_pages: 100)
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

  test "has many subjects" do
    assert_equal [ subjects(:cyberpunk), subjects(:science_fiction) ].sort_by(&:id), books(:two).subjects.sort_by(&:id)
  end

  test "subject_names links existing subjects and creates missing ones" do
    book = Book.new(title: "Snow Crash", total_pages: 100, subject_names: [ "Cyberpunk", "Satire" ])

    assert_difference({ "Subject.count" => 1, "BookSubject.count" => 2 }) { book.save! }
    assert_includes book.subjects, subjects(:cyberpunk)
    assert_equal [ "Cyberpunk", "Satire" ], book.subjects.map(&:name).sort
  end

  test "subject_names matches existing subjects ignoring extra whitespace" do
    book = Book.new(title: "Snow Crash", total_pages: 100, subject_names: [ "  Science   Fiction " ])

    assert_no_difference("Subject.count") { book.save! }
    assert_equal [ subjects(:science_fiction) ], book.subjects
  end

  test "subject_names skips blank and duplicate names" do
    book = Book.new(title: "Snow Crash", total_pages: 100, subject_names: [ "Satire", " ", nil, "Satire", " Satire " ])

    assert_difference({ "Subject.count" => 1, "BookSubject.count" => 1 }) { book.save! }
    assert_equal [ "Satire" ], book.subjects.map(&:name)
  end

  test "subject_names accepts a single name" do
    book = Book.new(title: "Snow Crash", total_pages: 100, subject_names: "Satire")

    book.save!
    assert_equal [ "Satire" ], book.subjects.map(&:name)
  end

  test "subject_names does not create subjects when the book is invalid" do
    book = Book.new(title: "", total_pages: 100, subject_names: [ "Satire" ])

    assert_no_difference(%w[Subject.count BookSubject.count]) do
      assert_not book.save
    end
  end

  test "removes its subject links but keeps the subjects when destroyed" do
    assert_difference("BookSubject.count", -2) do
      books(:two).destroy
    end
    assert Subject.exists?(subjects(:cyberpunk).id)
  end
end

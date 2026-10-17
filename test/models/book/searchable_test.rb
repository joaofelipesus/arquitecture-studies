require "test_helper"

class Book::SearchableTest < ActiveSupport::TestCase
  test "stores the lowercased title and author name when a book is created" do
    book = Book.create!(title: "Dune Messiah", total_pages: 100, author_name: "Frank Herbert")

    assert_equal "dune messiah frank herbert", book.reload.searchable
  end

  test "stores only the lowercased title when the book has no authors" do
    book = Book.create!(title: "Anonymous TALES", total_pages: 100)

    assert_equal "anonymous tales", book.reload.searchable
  end

  test "updates when the title changes" do
    books(:one).update!(title: "Dune: Deluxe Edition")

    assert_equal "dune: deluxe edition frank herbert", books(:one).reload.searchable
  end

  test "includes every author" do
    books(:one).update!(author_name: "Brian Herbert")

    # The authors come back in no guaranteed order, so only the title's position is fixed.
    searchable = books(:one).reload.searchable
    assert searchable.start_with?("dune ")
    assert_includes searchable, "frank herbert"
    assert_includes searchable, "brian herbert"
  end

  test "search finds books by part of the title or an author name, ignoring case" do
    dune = Book.create!(title: "Dune", total_pages: 100, author_name: "Frank Herbert")
    neuromancer = Book.create!(title: "Neuromancer", total_pages: 100, author_name: "William Gibson")

    assert_equal [ dune ], Book.search("dUn").to_a
    assert_equal [ neuromancer ], Book.search("GIBSON").to_a
  end

  test "search requires every word, in any order and across title and authors" do
    dune = Book.create!(title: "Dune", total_pages: 100, author_name: "Frank Herbert")
    Book.create!(title: "Dune Messiah", total_pages: 100, author_name: "Someone Else")

    assert_equal [ dune ], Book.search("herbert  dune").to_a
  end

  test "search returns nothing when no book matches" do
    Book.create!(title: "Dune", total_pages: 100, author_name: "Frank Herbert")

    assert_empty Book.search("asimov")
  end

  test "search returns every book when the term is blank" do
    assert_equal Book.count, Book.search(" ").count
    assert_equal Book.count, Book.search(nil).count
  end

  test "search matches LIKE wildcards literally" do
    discount = Book.create!(title: "100% Discount", total_pages: 10)
    Book.create!(title: "My_Book", total_pages: 10)

    assert_equal [ discount ], Book.search("0%").to_a
    assert_equal [ "My_Book" ], Book.search("_").pluck(:title)
  end
end

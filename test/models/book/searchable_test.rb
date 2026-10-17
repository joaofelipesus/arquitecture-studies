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
end

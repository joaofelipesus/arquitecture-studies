require "test_helper"

class BooksTest < ActionDispatch::IntegrationTest
  setup do
    @book = books(:one)
  end

  # Happy path

  test "lists all books" do
    get books_url, as: :json

    assert_response :ok
    assert_equal Book.pluck(:title).sort, response.parsed_body.pluck("title").sort
  end

  test "searches books by part of the title" do
    get search_books_url, params: { q: "dune" }

    assert_response :ok
    assert_equal [ "Dune" ], response.parsed_body.pluck("title")
    assert_equal [ "Frank Herbert" ], response.parsed_body.first["authors"].pluck("name")
  end

  test "searches books by part of the author name" do
    get search_books_url, params: { q: "GIBS" }

    assert_response :ok
    assert_equal [ "Neuromancer" ], response.parsed_body.pluck("title")
    assert_equal [ "William Gibson" ], response.parsed_body.first["authors"].pluck("name")
  end

  test "returns all authors of a book matched by one of its authors" do
    book = books(:two)
    book.author_name = "Bruce Sterling"
    book.save!

    get search_books_url, params: { q: "sterling" }

    assert_response :ok
    assert_equal [ "Neuromancer" ], response.parsed_body.pluck("title")
    assert_equal [ "Bruce Sterling", "William Gibson" ], response.parsed_body.first["authors"].pluck("name").sort
  end

  test "searches books by title and author words together" do
    get search_books_url, params: { q: "herbert dune" }

    assert_response :ok
    assert_equal [ "Dune" ], response.parsed_body.pluck("title")
  end

  test "returns an empty list when the words belong to different books" do
    get search_books_url, params: { q: "dune gibson" }

    assert_response :ok
    assert_empty response.parsed_body
  end

  test "returns an empty list when nothing matches the search" do
    get search_books_url, params: { q: "Foundation" }

    assert_response :ok
    assert_empty response.parsed_body
  end

  test "returns the closest titles first" do
    Book.create!(title: "Arrakis", total_pages: 100, author_name: "Dune Fan")
    Book.create!(title: "Children of Dune", total_pages: 100, author_name: "Frank Herbert")

    get search_books_url, params: { q: "dune" }

    assert_response :ok
    assert_equal [ "Dune", "Children of Dune", "Arrakis" ], response.parsed_body.pluck("title")
  end

  test "returns the reader counts of each book found" do
    UserBook.create!(user: users(:bob), book: books(:one), status: :finished, current_page: 412)

    get search_books_url, params: { q: "dune" }

    assert_response :ok
    expected = { "total" => 2, "want_to_read" => 0, "reading" => 1, "finished" => 1, "stopped" => 0 }
    assert_equal expected, response.parsed_body.first["readers"]
  end

  test "returns zero reader counts for a book nobody has" do
    book = Book.create!(title: "Foundation", total_pages: 255)

    get search_books_url, params: { q: "foundation" }

    assert_response :ok
    assert_equal [ book.id ], response.parsed_body.pluck("id")
    expected = { "total" => 0, "want_to_read" => 0, "reading" => 0, "finished" => 0, "stopped" => 0 }
    assert_equal expected, response.parsed_body.first["readers"]
  end

  test "lists all books when the search is blank" do
    get search_books_url, params: { q: " " }

    assert_response :ok
    assert_equal Book.count, response.parsed_body.size
  end

  test "shows a book" do
    get book_url(@book), as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal @book.id, body["id"]
    assert_equal "Dune", body["title"]
    assert_equal "1965-08-01", body["release_date"]
    assert_equal 412, body["total_pages"]
    assert_equal [ "Frank Herbert" ], body["authors"].pluck("name")
    assert_equal [ "Science Fiction" ], body["subjects"].pluck("name")
  end

  test "creates a book" do
    assert_difference("Book.count", 1) do
      post books_url, params: { book: { title: "Foundation", total_pages: 255, description: "Psychohistory.", release_date: "1951-05-01" } }, as: :json
    end

    assert_response :created
    book = Book.find(response.parsed_body["id"])
    assert_equal book_url(book), response.location
    assert_equal "Foundation", book.title
    assert_equal "Psychohistory.", book.description
    assert_equal Date.new(1951, 5, 1), book.release_date
    assert_equal 255, book.total_pages
  end

  test "creates a book linked to an existing author" do
    assert_no_difference("Author.count") do
      post books_url, params: { book: { title: "Dune Messiah", total_pages: 100, author_name: "Frank Herbert" } }, as: :json
    end

    assert_response :created
    assert_equal [ authors(:herbert).id ], response.parsed_body["authors"].pluck("id")
    assert_equal 2, authors(:herbert).books.count
  end

  test "creates a book and a new author" do
    assert_difference({ "Author.count" => 1, "AuthorBook.count" => 1 }) do
      post books_url, params: { book: { title: "Foundation", total_pages: 100, author_name: "Isaac Asimov" } }, as: :json
    end

    assert_response :created
    assert_equal [ "Isaac Asimov" ], response.parsed_body["authors"].pluck("name")
  end

  test "creates a book with author_name from an unwrapped JSON payload" do
    post books_url, params: { title: "Foundation", total_pages: 100, author_name: "Isaac Asimov" }, as: :json

    assert_response :created
    assert_equal [ "Isaac Asimov" ], response.parsed_body["authors"].pluck("name")
  end

  test "creates a book linked to existing and new subjects" do
    assert_difference({ "Subject.count" => 1, "BookSubject.count" => 2 }) do
      post books_url, params: { book: { title: "Snow Crash", total_pages: 100, subject_names: [ "Cyberpunk", "Satire" ] } }, as: :json
    end

    assert_response :created
    assert_equal [ "Cyberpunk", "Satire" ], response.parsed_body["subjects"].pluck("name").sort
    assert_includes subjects(:cyberpunk).books.pluck(:title), "Snow Crash"
  end

  test "creates a book with an author and subjects from an unwrapped JSON payload" do
    post books_url, params: { title: "Snow Crash", total_pages: 100, author_name: "Neal Stephenson", subject_names: [ "Cyberpunk" ] }, as: :json

    assert_response :created
    assert_equal [ "Neal Stephenson" ], response.parsed_body["authors"].pluck("name")
    assert_equal [ "Cyberpunk" ], response.parsed_body["subjects"].pluck("name")
  end

  test "creates a book without subjects" do
    post books_url, params: { book: { title: "Snow Crash", total_pages: 100 } }, as: :json

    assert_response :created
    assert_empty response.parsed_body["subjects"]
  end

  test "updates the total pages of a book" do
    patch book_url(@book), params: { book: { total_pages: 896 } }, as: :json

    assert_response :ok
    assert_equal 896, response.parsed_body["total_pages"]
    assert_equal 896, @book.reload.total_pages
  end

  test "updates a book" do
    patch book_url(@book), params: { book: { title: "Dune Messiah" } }, as: :json

    assert_response :ok
    assert_equal "Dune Messiah", response.parsed_body["title"]
    assert_equal "Dune Messiah", @book.reload.title
  end

  test "destroys a book" do
    assert_difference("Book.count", -1) do
      delete book_url(@book), as: :json
    end

    assert_response :no_content
  end

  test "creates a book from an unwrapped JSON payload" do
    assert_difference("Book.count", 1) do
      post books_url, params: { title: "Foundation", total_pages: 100 }, as: :json
    end

    assert_response :created
    assert_equal "Foundation", response.parsed_body["title"]
  end

  test "ignores unpermitted attributes" do
    post books_url, params: { book: { title: "Foundation", total_pages: 100, id: 999_999 } }, as: :json

    assert_response :created
    assert_not_equal 999_999, response.parsed_body["id"]
  end

  # Failing path

  test "does not create a book without a title" do
    assert_no_difference("Book.count") do
      post books_url, params: { book: { title: "", total_pages: 100, description: "No title." } }, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["title"], "can't be blank"
  end

  test "does not create a book without total pages" do
    assert_no_difference("Book.count") do
      post books_url, params: { book: { title: "Foundation" } }, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["total_pages"], "can't be blank"
  end

  test "does not create a book with invalid total pages" do
    assert_no_difference("Book.count") do
      post books_url, params: { book: { title: "Foundation", total_pages: 0 } }, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["total_pages"], "must be greater than 0"
  end

  test "does not update a book with invalid total pages" do
    patch book_url(@book), params: { book: { total_pages: -1 } }, as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body["total_pages"], "must be greater than 0"
    assert_equal 412, @book.reload.total_pages
  end

  test "does not create a book with an empty payload" do
    assert_no_difference("Book.count") do
      post books_url, params: {}, as: :json
    end

    assert_response :bad_request
  end

  test "does not create the author when the book is invalid" do
    assert_no_difference(%w[Book.count Author.count AuthorBook.count]) do
      post books_url, params: { book: { title: "", total_pages: 100, author_name: "Isaac Asimov" } }, as: :json
    end

    assert_response :unprocessable_content
  end

  test "does not create subjects when the book is invalid" do
    assert_no_difference(%w[Book.count Subject.count BookSubject.count]) do
      post books_url, params: { book: { title: "", total_pages: 100, subject_names: [ "Satire" ] } }, as: :json
    end

    assert_response :unprocessable_content
  end

  test "ignores subject_names that are not a list" do
    assert_no_difference("Subject.count") do
      post books_url, params: { book: { title: "Snow Crash", total_pages: 100, subject_names: "Satire" } }, as: :json
    end

    assert_response :created
    assert_empty response.parsed_body["subjects"]
  end

  test "ignores subject_names on update" do
    assert_no_difference(%w[Subject.count BookSubject.count]) do
      patch book_url(@book), params: { book: { title: "Dune (revised)", subject_names: [ "Satire" ] } }, as: :json
    end

    assert_response :ok
    assert_equal [ subjects(:science_fiction) ], @book.reload.subjects
  end

  test "ignores author_name on update" do
    assert_no_difference(%w[Author.count AuthorBook.count]) do
      patch book_url(@book), params: { book: { title: "Dune (revised)", author_name: "Isaac Asimov" } }, as: :json
    end

    assert_response :ok
    assert_equal [ authors(:herbert) ], @book.reload.authors
  end

  test "does not update a book with a blank title" do
    patch book_url(@book), params: { book: { title: "" } }, as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body["title"], "can't be blank"
    assert_equal "Dune", @book.reload.title
  end

  test "returns not found when showing a missing book" do
    get book_url(id: 0), as: :json

    assert_response :not_found
  end

  test "returns not found when updating a missing book" do
    patch book_url(id: 0), params: { book: { title: "Ghost" } }, as: :json

    assert_response :not_found
  end

  test "returns not found when destroying a missing book" do
    assert_no_difference("Book.count") do
      delete book_url(id: 0), as: :json
    end

    assert_response :not_found
  end
end

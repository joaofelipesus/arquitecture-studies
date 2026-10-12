require "test_helper"

class UserBooksTest < ActionDispatch::IntegrationTest
  setup do
    @user_book = user_books(:alice_dune)
  end

  # Happy path

  test "lists all user books" do
    get user_books_url, as: :json

    assert_response :ok
    assert_equal UserBook.pluck(:id).sort, response.parsed_body.pluck("id").sort
  end

  test "shows a user book" do
    get user_book_url(@user_book), as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal users(:alice).id, body["user_id"]
    assert_equal books(:one).id, body["book_id"]
    assert_equal "reading", body["status"]
    assert_equal "2026-09-01", body["started_at"]
    assert_equal 206, body["current_page"]
    assert_equal "50.0", body["current_progress"]
  end

  test "creates a user book with defaults" do
    assert_difference("UserBook.count", 1) do
      post user_books_url, params: { user_book: { user_id: users(:alice).id, book_id: books(:two).id } }, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal user_book_url(body["id"]), response.location
    assert_equal "want_to_read", body["status"]
    assert_equal 0, body["current_page"]
    assert_equal "0.0", body["current_progress"]
  end

  test "creates a user book with progress" do
    post user_books_url, params: { user_book: { user_id: users(:alice).id, book_id: books(:two).id, status: "reading", started_at: "2026-10-01", current_page: 50 } }, as: :json

    assert_response :created
    body = response.parsed_body
    assert_equal "reading", body["status"]
    assert_equal "2026-10-01", body["started_at"]
    assert_equal 50, body["current_page"]
    assert_equal "18.45", body["current_progress"]
  end

  test "creates a user book from an unwrapped JSON payload" do
    post user_books_url, params: { user_id: users(:alice).id, book_id: books(:two).id, status: "want_to_read" }, as: :json

    assert_response :created
    assert_equal "want_to_read", response.parsed_body["status"]
  end

  test "updates reading progress" do
    patch user_book_url(@user_book), params: { user_book: { current_page: 309 } }, as: :json

    assert_response :ok
    assert_equal 309, response.parsed_body["current_page"]
    assert_equal "75.0", response.parsed_body["current_progress"]
    assert_equal BigDecimal("75"), @user_book.reload.current_progress
  end

  test "finishes a book" do
    patch user_book_url(@user_book), params: { user_book: { status: "finished", finished_at: "2026-10-10", current_page: 412 } }, as: :json

    assert_response :ok
    @user_book.reload
    assert @user_book.finished?
    assert_equal Date.new(2026, 10, 10), @user_book.finished_at
    assert_equal 100, @user_book.current_progress
  end

  test "stops reading a book" do
    patch user_book_url(@user_book), params: { user_book: { status: "stopped" } }, as: :json

    assert_response :ok
    assert @user_book.reload.stopped?
  end

  test "destroys a user book but keeps the user and the book" do
    assert_difference({ "UserBook.count" => -1, "User.count" => 0, "Book.count" => 0 }) do
      delete user_book_url(@user_book), as: :json
    end

    assert_response :no_content
  end

  test "ignores current_progress sent by the client" do
    patch user_book_url(@user_book), params: { user_book: { current_page: 206, current_progress: 99 } }, as: :json

    assert_response :ok
    assert_equal "50.0", response.parsed_body["current_progress"]
  end

  test "ignores user_id and book_id on update" do
    patch user_book_url(@user_book), params: { user_book: { user_id: users(:bob).id, book_id: books(:two).id, status: "stopped" } }, as: :json

    assert_response :ok
    @user_book.reload
    assert_equal users(:alice), @user_book.user
    assert_equal books(:one), @user_book.book
  end

  test "updates progress" do
    patch update_progress_user_book_url(@user_book), params: { user_book: { current_page: 309 } }, as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal 309, body["current_page"]
    assert_equal "75.0", body["current_progress"]
    assert_equal "reading", body["status"]
  end

  test "updates progress from an unwrapped JSON payload" do
    patch update_progress_user_book_url(@user_book), params: { current_page: 103 }, as: :json

    assert_response :ok
    assert_equal "25.0", response.parsed_body["current_progress"]
  end

  test "finishes the book when progress reaches 100%" do
    travel_to Date.new(2026, 10, 12) do
      patch update_progress_user_book_url(@user_book), params: { current_page: 412 }, as: :json
    end

    assert_response :ok
    body = response.parsed_body
    assert_equal "100.0", body["current_progress"]
    assert_equal "finished", body["status"]
    assert_equal "2026-10-12", body["finished_at"]
  end

  test "update_progress only changes the page" do
    patch update_progress_user_book_url(@user_book), params: { user_book: { current_page: 300, status: "stopped", started_at: "2026-01-01" } }, as: :json

    assert_response :ok
    @user_book.reload
    assert @user_book.reading?
    assert_equal Date.new(2026, 9, 1), @user_book.started_at
  end

  # Failing path

  test "does not update progress beyond the book's total pages" do
    patch update_progress_user_book_url(@user_book), params: { current_page: 413 }, as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body["current_page"], "must be less than or equal to 412"
    @user_book.reload
    assert_equal 206, @user_book.current_page
    assert @user_book.reading?
  end

  test "does not update progress to a negative page" do
    patch update_progress_user_book_url(@user_book), params: { current_page: -1 }, as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body["current_page"], "must be greater than or equal to 0"
  end

  test "does not update progress without a current page" do
    patch update_progress_user_book_url(@user_book), params: {}, as: :json

    assert_response :bad_request
    assert_equal 206, @user_book.reload.current_page
  end

  test "returns not found when updating progress of a missing user book" do
    patch update_progress_user_book_url(id: 0), params: { current_page: 1 }, as: :json

    assert_response :not_found
  end


  test "does not create a user book without a user" do
    assert_no_difference("UserBook.count") do
      post user_books_url, params: { user_book: { book_id: books(:two).id } }, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["user"], "must exist"
  end

  test "does not create a user book for a missing book" do
    assert_no_difference("UserBook.count") do
      post user_books_url, params: { user_book: { user_id: users(:alice).id, book_id: 0 } }, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["book"], "must exist"
  end

  test "does not create a user book the user already has" do
    assert_no_difference("UserBook.count") do
      post user_books_url, params: { user_book: { user_id: users(:alice).id, book_id: books(:one).id } }, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["book_id"], "has already been taken"
  end

  test "does not create a user book with an unknown status" do
    assert_no_difference("UserBook.count") do
      post user_books_url, params: { user_book: { user_id: users(:alice).id, book_id: books(:two).id, status: "abandoned" } }, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["status"], "is not included in the list"
  end

  test "does not create a user book with an empty payload" do
    assert_no_difference("UserBook.count") do
      post user_books_url, params: {}, as: :json
    end

    assert_response :bad_request
  end

  test "does not update to a page beyond the book's total pages" do
    patch user_book_url(@user_book), params: { user_book: { current_page: 413 } }, as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body["current_page"], "must be less than or equal to 412"
    assert_equal 206, @user_book.reload.current_page
  end

  test "does not update to a negative page" do
    patch user_book_url(@user_book), params: { user_book: { current_page: -5 } }, as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body["current_page"], "must be greater than or equal to 0"
  end

  test "does not update with finished_at before started_at" do
    patch user_book_url(@user_book), params: { user_book: { status: "finished", finished_at: "2026-08-01" } }, as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body["finished_at"], "must be on or after started_at"
    assert @user_book.reload.reading?
  end

  test "returns not found when showing a missing user book" do
    get user_book_url(id: 0), as: :json

    assert_response :not_found
  end

  test "returns not found when updating a missing user book" do
    patch user_book_url(id: 0), params: { user_book: { status: "reading" } }, as: :json

    assert_response :not_found
  end

  test "returns not found when destroying a missing user book" do
    assert_no_difference("UserBook.count") do
      delete user_book_url(id: 0), as: :json
    end

    assert_response :not_found
  end
end

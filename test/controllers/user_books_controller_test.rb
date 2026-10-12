require "test_helper"

class UserBooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_book = user_books(:alice_dune)
  end

  test "should get index" do
    get user_books_url, as: :json
    assert_response :success
  end

  test "should create user_book" do
    assert_difference("UserBook.count") do
      post user_books_url, params: { user_book: { book_id: books(:two).id, current_page: 10, finished_at: nil, started_at: @user_book.started_at, status: "reading", user_id: @user_book.user_id } }, as: :json
    end

    assert_response :created
  end

  test "should show user_book" do
    get user_book_url(@user_book), as: :json
    assert_response :success
  end

  test "should update user_book" do
    patch user_book_url(@user_book), params: { user_book: { current_page: @user_book.current_page, finished_at: @user_book.finished_at, started_at: @user_book.started_at, status: @user_book.status } }, as: :json
    assert_response :success
  end

  test "should destroy user_book" do
    assert_difference("UserBook.count", -1) do
      delete user_book_url(@user_book), as: :json
    end

    assert_response :no_content
  end
end

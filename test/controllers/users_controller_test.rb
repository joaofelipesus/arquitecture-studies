require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
  end

  test "shows a user" do
    get user_url(@user)

    assert_response :ok
    body = response.parsed_body
    assert_equal @user.id, body["id"]
    assert_equal "alice", body["username"]
    assert_equal "Reads mostly science fiction.", body["bio"]
  end

  test "groups the user books by status, including empty statuses" do
    get user_url(@user)

    user_books = response.parsed_body["user_books"]
    assert_equal %w[ want_to_read reading finished stopped ], user_books.keys
    assert_equal [ user_books(:alice_dune).id ], user_books["reading"].pluck("id")
    assert_empty user_books["want_to_read"]
    assert_empty user_books["finished"]
    assert_empty user_books["stopped"]
  end

  test "shows the attributes and the book of each user book" do
    get user_url(@user)

    user_book = response.parsed_body["user_books"]["reading"].first
    assert_equal "reading", user_book["status"]
    assert_equal "2026-09-01", user_book["started_at"]
    assert_nil user_book["finished_at"]
    assert_equal 206, user_book["current_page"]
    assert_equal "50.0", user_book["current_progress"]
    assert_equal "Dune", user_book["book"]["title"]
    assert_equal 412, user_book["book"]["total_pages"]
    assert_equal [ "Frank Herbert" ], user_book["book"]["authors"].pluck("name")
    assert_equal [ "Science Fiction" ], user_book["book"]["subjects"].pluck("name")
  end

  test "orders each status by finished_at, then started_at, most recent first" do
    older = Book.create!(title: "Old", total_pages: 10)
    newer = Book.create!(title: "New", total_pages: 10)
    same_finish = Book.create!(title: "Same finish, later start", total_pages: 10)
    UserBook.create!(user: @user, book: older, status: :finished, current_page: 10, started_at: "2026-01-01", finished_at: "2026-02-01")
    UserBook.create!(user: @user, book: newer, status: :finished, current_page: 10, started_at: "2026-03-01", finished_at: "2026-04-01")
    UserBook.create!(user: @user, book: same_finish, status: :finished, current_page: 10, started_at: "2026-01-15", finished_at: "2026-02-01")

    get user_url(@user)

    assert_equal [ "New", "Same finish, later start", "Old" ], response.parsed_body["user_books"]["finished"].map { it["book"]["title"] }
  end

  test "orders user books without dates after the dated ones" do
    undated = Book.create!(title: "Undated", total_pages: 10)
    UserBook.create!(user: @user, book: undated, status: :reading)

    get user_url(@user)

    assert_equal [ "Dune", "Undated" ], response.parsed_body["user_books"]["reading"].map { it["book"]["title"] }
  end

  test "shows a user without user books" do
    user = User.create!(username: "carol")

    get user_url(user)

    assert_response :ok
    assert response.parsed_body["user_books"].values.all?(&:empty?)
  end

  test "returns not found when showing a missing user" do
    get user_url(id: 0)

    assert_response :not_found
  end
end

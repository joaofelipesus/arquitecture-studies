require "test_helper"

# Tests run with :null_store; these swap in a real store to check what GET /users/:id caches and when it expires.
class UserShowCacheTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @user = users(:alice)
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "serves a cached user without querying the database" do
    get user_url(@user), as: :json

    assert_no_queries { get user_url(@user), as: :json }
    assert_response :ok
    assert_equal "alice", response.parsed_body["username"]
    assert_equal [ "Dune" ], response.parsed_body["user_books"]["reading"].map { |user_book| user_book["book"]["title"] }
  end

  test "does not cache a missing user" do
    get user_url(id: 0), as: :json

    assert_response :not_found
    assert_not Rails.cache.exist?(User.show_cache_key("0"))
  end

  test "expires the cached user when it is updated" do
    get user_url(@user), as: :json
    @user.update!(bio: "Now into fantasy.")

    get user_url(@user), as: :json
    assert_equal "Now into fantasy.", response.parsed_body["bio"]
  end

  test "expires the cached user when one of their readings progresses" do
    get user_url(@user), as: :json
    patch update_progress_user_book_url(user_books(:alice_dune)), params: { user_book: { current_page: 412 } }, as: :json

    get user_url(@user), as: :json
    assert_empty response.parsed_body["user_books"]["reading"]
    assert_equal [ 412 ], response.parsed_body["user_books"]["finished"].pluck("current_page")
  end

  test "expires the cached user when they add a book" do
    get user_url(@user), as: :json
    UserBook.create!(user: @user, book: books(:two))

    get user_url(@user), as: :json
    assert_equal [ "Neuromancer" ], response.parsed_body["user_books"]["want_to_read"].map { |user_book| user_book["book"]["title"] }
  end

  test "expires the cached user when one of their books is updated" do
    get user_url(@user), as: :json
    books(:one).update!(title: "Dune Messiah")

    get user_url(@user), as: :json
    assert_equal [ "Dune Messiah" ], response.parsed_body["user_books"]["reading"].map { |user_book| user_book["book"]["title"] }
  end

  test "expires the cached user when an author of one of their books is updated" do
    get user_url(@user), as: :json
    authors(:herbert).update!(name: "Frank Patrick Herbert")

    get user_url(@user), as: :json
    authors = response.parsed_body["user_books"]["reading"].first["book"]["authors"].pluck("name")
    assert_equal [ "Frank Patrick Herbert" ], authors
  end

  test "keeps other users cached when a book they don't have changes" do
    get user_url(@user), as: :json
    books(:two).update!(title: "Count Zero")

    assert Rails.cache.exist?(User.show_cache_key(@user.id.to_s))
  end

  test "creating a book does not look for cached pages to expire" do
    assert_no_queries_match(/user_books/) do
      Book.create!(title: "Foundation", total_pages: 100, author_name: "Isaac Asimov", subject_names: [ "Science Fiction" ])
    end
  end
end

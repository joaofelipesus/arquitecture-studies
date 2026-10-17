require "test_helper"

# GET requests run their queries with the reading role (the Postgres replica outside tests, see
# config/initializers/multi_db.rb), other methods with the writing role (the primary).
class ReadReplicaTest < ActionDispatch::IntegrationTest
  # The URLs are built before each block: loading a fixture is a query too, run by the test outside any request.

  test "GET requests read from the replica" do
    user_book_url = user_book_url(user_books(:alice_dune))

    assert_equal [ :reading ], roles_used { get search_books_url, params: { q: "dune" } }
    assert_equal [ :reading ], roles_used { get search_users_url, params: { username: "ali" } }
    assert_equal [ :reading ], roles_used { get books_url, as: :json }
    assert_equal [ :reading ], roles_used { get user_book_url, as: :json }
  end

  test "showing a book or a user reads from the primary, so a cached page is never stale" do
    book_url = book_url(books(:one))
    user_url = user_url(users(:alice))

    assert_equal [ :writing ], roles_used { get book_url, as: :json }
    assert_equal [ :writing ], roles_used { get user_url, as: :json }
  end

  test "POST, PATCH and DELETE requests use the primary" do
    book_url = book_url(books(:two))
    progress_url = update_progress_user_book_url(user_books(:alice_dune))

    assert_equal [ :writing ], roles_used { post books_url, params: { book: { title: "Foundation", total_pages: 255 } }, as: :json }
    assert_equal [ :writing ], roles_used { patch book_url, params: { book: { title: "Count Zero" } }, as: :json }
    assert_equal [ :writing ], roles_used { patch progress_url, params: { user_book: { current_page: 300 } }, as: :json }
    assert_equal [ :writing ], roles_used { delete book_url, as: :json }
  end

  private
    # The connection roles of every query run inside the block.
    def roles_used(&)
      roles = []
      ActiveSupport::Notifications.subscribed(->(*) { roles << ActiveRecord::Base.current_role }, "sql.active_record", &)
      roles.uniq
    end
end

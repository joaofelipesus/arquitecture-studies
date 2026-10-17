require "test_helper"

# Tests run with :null_store; these swap in a real store to check what GET /books/:id caches and when it expires.
class BookShowCacheTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @book = books(:one)
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "serves a cached book without querying the database" do
    get book_url(@book), as: :json

    assert_no_queries { get book_url(@book), as: :json }
    assert_response :ok
    assert_equal "Dune", response.parsed_body["title"]
    assert_equal [ "Frank Herbert" ], response.parsed_body["authors"].pluck("name")
  end

  test "does not cache a missing book" do
    get book_url(id: 0), as: :json

    assert_response :not_found
    assert_not Rails.cache.exist?(Book.show_cache_key("0"))
  end

  test "expires the cached book when it is updated" do
    get book_url(@book), as: :json
    patch book_url(@book), params: { book: { title: "Dune Messiah" } }, as: :json

    get book_url(@book), as: :json
    assert_equal "Dune Messiah", response.parsed_body["title"]
  end

  test "expires the cached book when it is destroyed" do
    get book_url(@book), as: :json
    delete book_url(@book), as: :json

    get book_url(@book), as: :json
    assert_response :not_found
  end

  test "expires the cached book when one of its authors is updated" do
    get book_url(@book), as: :json
    authors(:herbert).update!(name: "Frank Patrick Herbert")

    get book_url(@book), as: :json
    assert_equal [ "Frank Patrick Herbert" ], response.parsed_body["authors"].pluck("name")
  end

  test "expires the cached book when an author is linked" do
    get book_url(@book), as: :json
    @book.update!(author_name: "Brian Herbert")

    get book_url(@book), as: :json
    assert_equal [ "Brian Herbert", "Frank Herbert" ], response.parsed_body["authors"].pluck("name").sort
  end

  test "expires the cached book when one of its subjects is updated" do
    get book_url(@book), as: :json
    subjects(:science_fiction).update!(name: "Sci-Fi")

    get book_url(@book), as: :json
    assert_equal [ "Sci-Fi" ], response.parsed_body["subjects"].pluck("name")
  end

  test "expires the cached book when a subject is linked" do
    get book_url(@book), as: :json
    @book.update!(subject_names: [ "Space Opera" ])

    get book_url(@book), as: :json
    assert_includes response.parsed_body["subjects"].pluck("name"), "Space Opera"
  end
end

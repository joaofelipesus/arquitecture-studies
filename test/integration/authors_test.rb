require "test_helper"

class AuthorsTest < ActionDispatch::IntegrationTest
  setup do
    @author = authors(:herbert)
  end

  # Happy path

  test "lists all authors with their books" do
    get authors_url, as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal Author.pluck(:name).sort, body.pluck("name").sort
    herbert = body.find { |author| author["id"] == @author.id }
    assert_equal [ "Dune" ], herbert["books"].pluck("title")
  end

  test "shows an author with their books" do
    get author_url(@author), as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal "Frank Herbert", body["name"]
    assert_equal @author.biography, body["biography"]
    assert_equal [ "Dune" ], body["books"].pluck("title")
  end

  test "creates an author" do
    assert_difference("Author.count", 1) do
      post authors_url, params: { author: { name: "Isaac Asimov", biography: "Wrote Foundation." } }, as: :json
    end

    assert_response :created
    author = Author.find(response.parsed_body["id"])
    assert_equal author_url(author), response.location
    assert_equal "Isaac Asimov", author.name
    assert_equal "Wrote Foundation.", author.biography
    assert_empty response.parsed_body["books"]
  end

  test "creates an author from an unwrapped JSON payload" do
    post authors_url, params: { name: "Isaac Asimov" }, as: :json

    assert_response :created
    assert_equal "Isaac Asimov", response.parsed_body["name"]
  end

  test "squishes whitespace in the name on create" do
    post authors_url, params: { author: { name: "  Isaac   Asimov " } }, as: :json

    assert_response :created
    assert_equal "Isaac Asimov", response.parsed_body["name"]
  end

  test "updates an author" do
    patch author_url(@author), params: { author: { biography: "Updated biography." } }, as: :json

    assert_response :ok
    assert_equal "Updated biography.", response.parsed_body["biography"]
    assert_equal "Updated biography.", @author.reload.biography
  end

  test "destroys an author and its book links but keeps the books" do
    assert_difference({ "Author.count" => -1, "AuthorBook.count" => -1, "Book.count" => 0 }) do
      delete author_url(@author), as: :json
    end

    assert_response :no_content
  end

  test "books created with an author_name show up on the author" do
    post books_url, params: { book: { title: "Dune Messiah", author_name: "Frank Herbert" } }, as: :json
    get author_url(@author), as: :json

    assert_equal [ "Dune", "Dune Messiah" ], response.parsed_body["books"].pluck("title").sort
  end

  # Failing path

  test "does not create an author without a name" do
    assert_no_difference("Author.count") do
      post authors_url, params: { author: { name: "", biography: "Nobody." } }, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["name"], "can't be blank"
  end

  test "does not create an author with a duplicate name" do
    assert_no_difference("Author.count") do
      post authors_url, params: { author: { name: "Frank Herbert" } }, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["name"], "has already been taken"
  end

  test "does not create an author with an empty payload" do
    assert_no_difference("Author.count") do
      post authors_url, params: {}, as: :json
    end

    assert_response :bad_request
  end

  test "does not update an author with a blank name" do
    patch author_url(@author), params: { author: { name: "" } }, as: :json

    assert_response :unprocessable_content
    assert_equal "Frank Herbert", @author.reload.name
  end

  test "does not update an author to a name that is already taken" do
    patch author_url(@author), params: { author: { name: "William Gibson" } }, as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body["name"], "has already been taken"
    assert_equal "Frank Herbert", @author.reload.name
  end

  test "returns not found when showing a missing author" do
    get author_url(id: 0), as: :json

    assert_response :not_found
  end

  test "returns not found when updating a missing author" do
    patch author_url(id: 0), params: { author: { name: "Ghost" } }, as: :json

    assert_response :not_found
  end

  test "returns not found when destroying a missing author" do
    assert_no_difference("Author.count") do
      delete author_url(id: 0), as: :json
    end

    assert_response :not_found
  end
end

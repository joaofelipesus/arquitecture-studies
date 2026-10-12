require "test_helper"

class UserBookTest < ActiveSupport::TestCase
  setup do
    @user_book = UserBook.new(user: users(:alice), book: books(:two))
  end

  test "is valid with a user and a book" do
    assert @user_book.valid?
  end

  test "defaults to want_to_read with no pages read" do
    assert @user_book.want_to_read?
    assert_equal 0, @user_book.current_page
    assert_equal 0, @user_book.current_progress
  end

  test "is invalid without a user" do
    @user_book.user = nil

    assert_not @user_book.valid?
  end

  test "is invalid without a book" do
    @user_book.book = nil

    assert_not @user_book.valid?
  end

  test "is invalid when the user already has the book" do
    user_book = UserBook.new(user: users(:alice), book: books(:one))

    assert_not user_book.valid?
    assert_includes user_book.errors[:book_id], "has already been taken"
  end

  test "allows another user to have the same book" do
    assert UserBook.new(user: users(:bob), book: books(:one)).valid?
  end

  # Status

  test "accepts every status" do
    %w[want_to_read reading finished stopped].each do |status|
      @user_book.status = status

      assert @user_book.valid?, "expected #{status} to be valid"
    end
  end

  test "is invalid with an unknown status" do
    @user_book.status = "abandoned"

    assert_not @user_book.valid?
    assert_includes @user_book.errors[:status], "is not included in the list"
  end

  # current_page and current_progress

  test "calculates current_progress from current_page" do
    @user_book.current_page = 100
    @user_book.validate

    assert_equal BigDecimal("36.9"), @user_book.current_progress # 100 / 271
  end

  test "current_progress is 100 on the last page" do
    @user_book.current_page = 271
    @user_book.validate

    assert_equal 100, @user_book.current_progress
  end

  test "current_progress is stored when saved" do
    @user_book.update!(current_page: 50)

    assert_equal BigDecimal("18.45"), @user_book.reload.current_progress # 50 / 271
  end

  test "recalculates current_progress when current_page changes" do
    user_book = user_books(:alice_dune)
    user_book.update!(current_page: 103)

    assert_equal 25, user_book.current_progress # 103 / 412
  end

  test "ignores a current_progress set by hand" do
    @user_book.current_page = 0
    @user_book.current_progress = 80
    @user_book.validate

    assert_equal 0, @user_book.current_progress
  end

  test "is invalid with a negative current_page" do
    @user_book.current_page = -1

    assert_not @user_book.valid?
    assert_includes @user_book.errors[:current_page], "must be greater than or equal to 0"
  end

  test "is invalid with a fractional current_page" do
    @user_book.current_page = 10.5

    assert_not @user_book.valid?
    assert_includes @user_book.errors[:current_page], "must be an integer"
  end

  test "is invalid with a current_page beyond the book's total pages" do
    @user_book.current_page = 272

    assert_not @user_book.valid?
    assert_includes @user_book.errors[:current_page], "must be less than or equal to 271"
  end

  # Dates

  test "is valid when finished_at is after started_at" do
    @user_book.started_at = Date.new(2026, 9, 1)
    @user_book.finished_at = Date.new(2026, 9, 30)

    assert @user_book.valid?
  end

  test "is valid when finished_at is the same day as started_at" do
    @user_book.started_at = @user_book.finished_at = Date.new(2026, 9, 1)

    assert @user_book.valid?
  end

  test "is invalid when finished_at is before started_at" do
    @user_book.started_at = Date.new(2026, 9, 30)
    @user_book.finished_at = Date.new(2026, 9, 1)

    assert_not @user_book.valid?
    assert_includes @user_book.errors[:finished_at], "must be on or after started_at"
  end

  # update_progress

  test "update_progress saves the page and progress" do
    user_book = user_books(:alice_dune)

    assert user_book.update_progress(309)
    user_book.reload
    assert_equal 309, user_book.current_page
    assert_equal 75, user_book.current_progress
    assert user_book.reading?
  end

  test "update_progress finishes the book on the last page" do
    user_book = user_books(:alice_dune)

    travel_to Date.new(2026, 10, 12) do
      assert user_book.update_progress(412)
    end
    user_book.reload
    assert user_book.finished?
    assert_equal 100, user_book.current_progress
    assert_equal Date.new(2026, 10, 12), user_book.finished_at
  end

  test "update_progress keeps an existing finished_at" do
    user_book = user_books(:alice_dune)
    user_book.update!(finished_at: Date.new(2026, 10, 1))

    assert user_book.update_progress(412)
    assert_equal Date.new(2026, 10, 1), user_book.reload.finished_at
  end

  test "update_progress finishes a book from any status" do
    %w[want_to_read stopped].each do |status|
      user_book = UserBook.create!(user: users(:bob), book: books(:one), status: status)

      assert user_book.update_progress(412)
      assert user_book.reload.finished?, "expected #{status} to become finished"
      user_book.destroy!
    end
  end

  test "update_progress does not change the status before the last page" do
    user_book = UserBook.create!(user: users(:bob), book: books(:one), status: :want_to_read)

    assert user_book.update_progress(411)
    assert user_book.reload.want_to_read?
    assert_nil user_book.finished_at
  end

  test "update_progress does not touch an already finished book" do
    user_book = user_books(:bob_neuromancer)

    assert user_book.update_progress(271)
    assert_equal Date.new(2026, 8, 20), user_book.reload.finished_at
  end

  test "update_progress does not save a page beyond the book" do
    user_book = user_books(:alice_dune)

    assert_not user_book.update_progress(413)
    assert_includes user_book.errors[:current_page], "must be less than or equal to 412"
    user_book.reload
    assert_equal 206, user_book.current_page
    assert user_book.reading?
  end

  test "update_progress does not save a non-numeric page" do
    user_book = user_books(:alice_dune)

    assert_not user_book.update_progress("abc")
    assert_includes user_book.errors[:current_page], "is not a number"
    assert_equal 206, user_book.reload.current_page
  end

  # Associations

  test "is removed when its user is destroyed" do
    assert_difference("UserBook.count", -1) { users(:alice).destroy }
  end

  test "is removed when its book is destroyed" do
    assert_difference("UserBook.count", -1) { books(:one).destroy }
  end

  test "users have many books through their user books" do
    assert_equal [ books(:one) ], users(:alice).books
  end
end

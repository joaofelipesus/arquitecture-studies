require "test_helper"

class BookSubjectTest < ActiveSupport::TestCase
  test "is valid with a book and a subject" do
    assert BookSubject.new(book: books(:one), subject: subjects(:cyberpunk)).valid?
  end

  test "is invalid without a book" do
    assert_not BookSubject.new(subject: subjects(:cyberpunk)).valid?
  end

  test "is invalid without a subject" do
    assert_not BookSubject.new(book: books(:one)).valid?
  end

  test "is invalid when linking the same book and subject twice" do
    book_subject = BookSubject.new(book: books(:one), subject: subjects(:science_fiction))

    assert_not book_subject.valid?
    assert_includes book_subject.errors[:subject_id], "has already been taken"
  end
end

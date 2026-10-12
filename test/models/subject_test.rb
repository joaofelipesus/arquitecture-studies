require "test_helper"

class SubjectTest < ActiveSupport::TestCase
  test "is valid with a name" do
    assert Subject.new(name: "Fantasy").valid?
  end

  test "is invalid without a name" do
    subject = Subject.new(name: " ")

    assert_not subject.valid?
    assert_includes subject.errors[:name], "can't be blank"
  end

  test "is invalid with a name that already exists" do
    subject = Subject.new(name: subjects(:cyberpunk).name)

    assert_not subject.valid?
    assert_includes subject.errors[:name], "has already been taken"
  end

  test "squishes whitespace in the name" do
    assert_equal "Hard Science Fiction", Subject.new(name: "  Hard   Science Fiction ").name
  end

  test "has many books" do
    assert_equal [ books(:one), books(:two) ].sort_by(&:id), subjects(:science_fiction).books.sort_by(&:id)
  end

  test "removes its book links but keeps the books when destroyed" do
    assert_difference("BookSubject.count", -2) do
      subjects(:science_fiction).destroy
    end
    assert Book.exists?(books(:one).id)
  end
end

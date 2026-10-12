class Book < ApplicationRecord
  has_many :author_books, dependent: :destroy
  has_many :authors, through: :author_books
  has_many :book_subjects, dependent: :destroy
  has_many :subjects, through: :book_subjects

  validates :title, presence: true

  # Links the book to the author with this name, creating the author when it doesn't exist yet.
  def author_name=(name)
    return if name.blank?

    author = Author.find_or_initialize_by(name: name.squish)
    authors << author unless authors.include?(author)
  end

  # Links the book to the subjects with these names, creating the ones that don't exist yet.
  def subject_names=(names)
    Array(names).filter_map { |name| name.to_s.squish.presence }.uniq.each do |name|
      subject = Subject.find_or_initialize_by(name: name)
      subjects << subject unless subjects.include?(subject)
    end
  end
end

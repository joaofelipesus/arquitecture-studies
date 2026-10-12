class Book < ApplicationRecord
  has_many :author_books, dependent: :destroy
  has_many :authors, through: :author_books

  validates :title, presence: true

  # Links the book to the author with this name, creating the author when it doesn't exist yet.
  def author_name=(name)
    return if name.blank?

    author = Author.find_or_initialize_by(name: name.squish)
    authors << author unless authors.include?(author)
  end
end

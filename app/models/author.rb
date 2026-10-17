class Author < ApplicationRecord
  has_many :author_books, dependent: :destroy
  has_many :books, through: :author_books

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, uniqueness: true

  # The cached book and user pages include the author's name and biography.
  after_update_commit { Book.expire_cached_pages(book_ids) }
end

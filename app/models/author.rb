class Author < ApplicationRecord
  has_many :author_books, dependent: :destroy
  has_many :books, through: :author_books

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, uniqueness: true

  # The cached book pages include the author's name and biography.
  after_update_commit { Book.expire_show_cache(book_ids) }
end

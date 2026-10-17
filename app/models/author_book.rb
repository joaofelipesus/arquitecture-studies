class AuthorBook < ApplicationRecord
  belongs_to :author
  belongs_to :book

  validates :author_id, uniqueness: { scope: :book_id }

  # Linking or unlinking an author changes the book's cached pages. Skipped for a book created along with the
  # link (POST /books), which can't be cached yet.
  after_commit -> { Book.expire_cached_pages(book_id) }, unless: -> { book.previously_new_record? }
end

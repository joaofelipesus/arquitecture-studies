class BookSubject < ApplicationRecord
  belongs_to :book
  belongs_to :subject

  validates :subject_id, uniqueness: { scope: :book_id }

  # Linking or unlinking a subject changes the book's cached pages. Skipped for a book created along with the
  # link (POST /books), which can't be cached yet.
  after_commit -> { Book.expire_cached_pages(book_id) }, unless: -> { book.previously_new_record? }
end

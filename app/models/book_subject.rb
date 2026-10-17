class BookSubject < ApplicationRecord
  belongs_to :book
  belongs_to :subject

  validates :subject_id, uniqueness: { scope: :book_id }

  # Linking or unlinking a subject changes the book's cached page.
  after_commit { Book.expire_show_cache(book_id) }
end

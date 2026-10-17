class AuthorBook < ApplicationRecord
  belongs_to :author
  belongs_to :book

  validates :author_id, uniqueness: { scope: :book_id }

  # Linking or unlinking an author changes the book's cached page.
  after_commit { Book.expire_show_cache(book_id) }
end

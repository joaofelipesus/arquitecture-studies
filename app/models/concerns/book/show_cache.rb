# Caches the GET /books/:id response in Rails.cache (Redis), so showing a cached book doesn't touch the database.
# The entry is deleted whenever the book, its authors or its subjects change: here for the book itself, and in
# Author, Subject, AuthorBook and BookSubject for the rest. The GET /users/:id pages embed the books too, so the
# pages of the users who have the book are deleted along with it.
module Book::ShowCache
  extend ActiveSupport::Concern

  included do
    after_commit :expire_cached_pages, on: %i[ update destroy ]
  end

  class_methods do
    def show_cache_key(id)
      "books/show/#{id}"
    end

    def expire_cached_pages(ids)
      ids = Array(ids)
      Rails.cache.delete_multi(ids.map { |id| show_cache_key(id) })
      User.expire_show_cache(UserBook.where(book_id: ids).distinct.pluck(:user_id))
    end
  end

  private
    def expire_cached_pages
      self.class.expire_cached_pages(id)
    end
end

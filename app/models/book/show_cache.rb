# Caches the GET /books/:id response in Rails.cache (Redis), so showing a cached book doesn't touch the database.
# The entry is deleted whenever the book, its authors or its subjects change: here for the book itself, and in
# Author, Subject, AuthorBook and BookSubject for the rest.
module Book::ShowCache
  extend ActiveSupport::Concern

  included do
    after_commit :expire_show_cache, on: %i[ update destroy ]
  end

  class_methods do
    def show_cache_key(id)
      "books/show/#{id}"
    end

    def expire_show_cache(ids)
      Rails.cache.delete_multi(Array(ids).map { |id| show_cache_key(id) })
    end
  end

  private
    def expire_show_cache
      self.class.expire_show_cache(id)
    end
end

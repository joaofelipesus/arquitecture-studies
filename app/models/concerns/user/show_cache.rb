# Caches the GET /users/:id response in Rails.cache (Redis), so showing a cached user doesn't touch the database.
# The page lists the user's readings with their books, so the entry is deleted when the user, one of their
# readings (UserBook) or one of those books changes (Book::ShowCache.expire_cached_pages).
module User::ShowCache
  extend ActiveSupport::Concern

  included do
    after_commit :expire_show_cache, on: %i[ update destroy ]
  end

  class_methods do
    def show_cache_key(id)
      "users/show/#{id}"
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

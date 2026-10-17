# Keeps books.searchable in sync with the title and the author names, lowercased in a single column:
# "dune frank herbert". Rebuilt every time the book is created or updated.
module Book::Searchable
  extend ActiveSupport::Concern

  included do
    before_save :set_searchable
  end

  private
    def set_searchable
      self.searchable = [ title, *authors.map(&:name) ].join(" ").downcase
    end
end

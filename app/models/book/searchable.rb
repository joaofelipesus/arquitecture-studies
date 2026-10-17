# Keeps books.searchable in sync with the title and the author names, lowercased in a single column:
# "dune frank herbert". Rebuilt every time the book is created or updated.
module Book::Searchable
  extend ActiveSupport::Concern

  included do
    before_save :set_searchable
  end

  class_methods do
    # Books whose title or author names contain every word of the term, ignoring case: "dune herbert"
    # matches "dune frank herbert". A blank term returns every book.
    def search(term)
      term.to_s.downcase.split.reduce(all) do |books, word|
        books.where("books.searchable LIKE ?", "%#{sanitize_sql_like(word)}%")
      end
    end
  end

  private
    def set_searchable
      self.searchable = [ title, *authors.map(&:name) ].join(" ").downcase
    end
end

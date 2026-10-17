# Keeps books.searchable in sync with the title and the author names, lowercased in a single column:
# "dune frank herbert". Rebuilt every time the book is created or updated.
module Book::Searchable
  extend ActiveSupport::Concern

  included do
    before_save :set_searchable
  end

  class_methods do
    # Books whose title or author names contain every word of the term, ignoring case: "dune herbert"
    # matches "dune frank herbert". The closest titles come first, so "Dune" ranks above "Children of Dune"
    # and books matched only by an author come last. A blank term returns every book.
    def search(term)
      words = term.to_s.downcase.split
      return all if words.empty?

      words
        .reduce(all) { |books, word| books.where("books.searchable LIKE ?", "%#{sanitize_sql_like(word)}%") }
        .order(sanitize_sql_for_order([ Arel.sql("similarity(books.title, ?) DESC, books.id"), words.join(" ") ]))
    end
  end

  private
    def set_searchable
      self.searchable = [ title, *authors.map(&:name) ].join(" ").downcase
    end
end

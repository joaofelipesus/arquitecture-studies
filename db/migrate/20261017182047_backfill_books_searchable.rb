# Fills books.searchable for the books saved before Book::Searchable existed, the same way its callback
# does ("title author1 author2 ...", lowercased), in a single UPDATE instead of saving each book.
class BackfillBooksSearchable < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE books
      SET searchable = lower(concat_ws(' ', books.title, book_authors.names))
      FROM books AS all_books
      LEFT JOIN (
        SELECT author_books.book_id, string_agg(authors.name, ' ' ORDER BY author_books.id) AS names
        FROM author_books
        JOIN authors ON authors.id = author_books.author_id
        GROUP BY author_books.book_id
      ) AS book_authors ON book_authors.book_id = all_books.id
      WHERE books.id = all_books.id
    SQL
  end

  def down
    # Nothing to undo: the column stays, and the callback keeps it up to date.
  end
end

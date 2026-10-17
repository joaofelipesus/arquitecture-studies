# Trigram index so Book.search's `searchable LIKE '%word%'` uses an index instead of scanning every book.
class AddTrigramIndexToBooksSearchable < ActiveRecord::Migration[8.1]
  # CREATE INDEX CONCURRENTLY can't run inside a transaction; it keeps the table writable while the index builds.
  disable_ddl_transaction!

  def change
    enable_extension "pg_trgm"
    add_index :books, :searchable, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
  end
end

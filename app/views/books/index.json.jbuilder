# @readers is only set by books#search; it adds how many users have each book, in total and per status.
json.array! @books do |book|
  json.partial! "books/book", book: book
  json.readers @readers.fetch(book.id) if @readers
end

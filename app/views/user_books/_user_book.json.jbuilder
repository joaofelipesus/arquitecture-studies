json.id user_book.id
json.status user_book.status
json.started_at user_book.started_at
json.finished_at user_book.finished_at
json.current_page user_book.current_page
json.current_progress user_book.current_progress
json.created_at user_book.created_at
json.updated_at user_book.updated_at

json.book do
  json.partial! "books/book", book: user_book.book
end

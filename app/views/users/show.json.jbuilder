json.partial! "users/user", user: @user

json.user_books do
  UserBook.statuses.each_key do |status|
    json.set! status, @user_books_by_status.fetch(status, []), partial: "user_books/user_book", as: :user_book
  end
end

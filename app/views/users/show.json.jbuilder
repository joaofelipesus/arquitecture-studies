json.id @user.id
json.username @user.username
json.bio @user.bio
json.created_at @user.created_at
json.updated_at @user.updated_at

json.user_books do
  UserBook.statuses.each_key do |status|
    json.set! status, @user_books_by_status.fetch(status, []), partial: "user_books/user_book", as: :user_book
  end
end

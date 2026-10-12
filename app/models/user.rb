class User < ApplicationRecord
  has_many :user_books, dependent: :destroy
  has_many :books, through: :user_books

  normalizes :username, with: ->(username) { username.strip }

  validates :username, presence: true, uniqueness: true
end

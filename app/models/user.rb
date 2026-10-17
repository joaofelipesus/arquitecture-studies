class User < ApplicationRecord
  include ShowCache

  has_many :user_books, dependent: :destroy
  has_many :books, through: :user_books

  normalizes :username, with: ->(username) { username.strip }

  validates :username, presence: true, uniqueness: true

  scope :username_contains, ->(term) { where("users.username ILIKE ?", "%#{sanitize_sql_like(term)}%") }
end

class User < ApplicationRecord
  normalizes :username, with: ->(username) { username.strip }

  validates :username, presence: true, uniqueness: true
end

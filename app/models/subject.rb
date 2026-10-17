class Subject < ApplicationRecord
  has_many :book_subjects, dependent: :destroy
  has_many :books, through: :book_subjects

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, uniqueness: true

  # The cached book pages include the subject's name.
  after_update_commit { Book.expire_show_cache(book_ids) }
end

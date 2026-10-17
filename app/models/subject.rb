class Subject < ApplicationRecord
  has_many :book_subjects, dependent: :destroy
  has_many :books, through: :book_subjects

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, uniqueness: true

  # The cached book and user pages include the subject's name.
  after_update_commit { Book.expire_cached_pages(book_ids) }
end

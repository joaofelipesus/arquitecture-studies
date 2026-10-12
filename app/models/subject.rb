class Subject < ApplicationRecord
  has_many :book_subjects, dependent: :destroy
  has_many :books, through: :book_subjects

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, uniqueness: true
end

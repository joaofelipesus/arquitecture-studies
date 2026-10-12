class BookSubject < ApplicationRecord
  belongs_to :book
  belongs_to :subject

  validates :subject_id, uniqueness: { scope: :book_id }
end

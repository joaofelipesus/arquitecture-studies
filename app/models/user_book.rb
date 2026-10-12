class UserBook < ApplicationRecord
  belongs_to :user
  belongs_to :book

  enum :status, {
    want_to_read: "want_to_read",
    reading: "reading",
    finished: "finished",
    stopped: "stopped"
  }, default: :want_to_read, validate: true

  before_validation :calculate_current_progress

  validates :book_id, uniqueness: { scope: :user_id }
  validates :current_page, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :current_page_within_book
  validate :finished_at_not_before_started_at

  # Moves the reading to the given page; reaching the last page finishes the book.
  def update_progress(page)
    self.current_page = page
    calculate_current_progress

    if current_progress == 100 && !finished?
      self.status = :finished
      self.finished_at ||= Date.current
    end

    save
  end

  private
    # current_progress is the percentage of the book read, derived from current_page.
    def calculate_current_progress
      return unless book && current_page

      self.current_progress = (current_page.to_d / book.total_pages * 100).round(2)
    end

    def current_page_within_book
      return unless book && current_page

      errors.add(:current_page, "must be less than or equal to #{book.total_pages}") if current_page > book.total_pages
    end

    def finished_at_not_before_started_at
      return unless started_at && finished_at

      errors.add(:finished_at, "must be on or after started_at") if finished_at < started_at
    end
end

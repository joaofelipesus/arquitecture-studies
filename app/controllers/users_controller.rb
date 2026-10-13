class UsersController < ApplicationController
  before_action :set_user, only: %i[ show ]

  # GET /users/1
  # Lists the user's books grouped by status, most recently finished, then started, first.
  def show
    @user_books_by_status = @user.user_books.includes(book: %i[ authors subjects ]).most_recent_first.group_by(&:status)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params.expect(:id))
    end
end

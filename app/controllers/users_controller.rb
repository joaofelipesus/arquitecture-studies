class UsersController < ApplicationController
  around_action :read_from_primary, only: %i[ show ]

  # GET /users/search?username=ali
  def search
    @users = User.order(:username)
    @users = @users.username_contains(params[:username]) if params[:username].present?
  end

  # GET /users/1
  # Lists the user's books grouped by status, most recently finished, then started, first.
  # Served from Rails.cache (Redis) when it's there, without touching the database; otherwise the user is loaded
  # and rendered, and the JSON cached. User::ShowCache deletes the entry whenever the page would change.
  def show
    json = Rails.cache.fetch(User.show_cache_key(params.expect(:id)), expires_in: 12.hours) do
      @user = User.find(params.expect(:id))
      @user_books_by_status = @user.user_books.includes(book: %i[ authors subjects ]).most_recent_first.group_by(&:status)
      render_to_string(:show)
    end

    render json: json
  end
end

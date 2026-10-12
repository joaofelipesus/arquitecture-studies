class UserBooksController < ApplicationController
  before_action :set_user_book, only: %i[ show update update_progress destroy ]

  # GET /user_books
  def index
    @user_books = UserBook.all

    render json: @user_books
  end

  # GET /user_books/1
  def show
    render json: @user_book
  end

  # POST /user_books
  def create
    @user_book = UserBook.new(new_user_book_params)

    if @user_book.save
      render json: @user_book, status: :created, location: @user_book
    else
      render json: @user_book.errors, status: :unprocessable_content
    end
  end

  # PATCH/PUT /user_books/1
  def update
    if @user_book.update(user_book_params)
      render json: @user_book
    else
      render json: @user_book.errors, status: :unprocessable_content
    end
  end

  # PATCH /user_books/1/update_progress
  def update_progress
    if @user_book.update_progress(params.expect(user_book: [ :current_page ])[:current_page])
      render json: @user_book
    else
      render json: @user_book.errors, status: :unprocessable_content
    end
  end

  # DELETE /user_books/1
  def destroy
    @user_book.destroy!
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user_book
      @user_book = UserBook.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    # current_progress is calculated from current_page, and the user/book of an entry can't be changed.
    def user_book_params
      params.expect(user_book: [ :status, :started_at, :finished_at, :current_page ])
    end

    def new_user_book_params
      params.expect(user_book: [ :user_id, :book_id, :status, :started_at, :finished_at, :current_page ])
    end
end

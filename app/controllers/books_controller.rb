class BooksController < ApplicationController
  wrap_parameters include: %i[ title description release_date total_pages author_name subject_names ]

  before_action :set_book, only: %i[ show update destroy ]

  # GET /books
  def index
    @books = Book.includes(:authors, :subjects)

    render json: @books, include: %i[ authors subjects ]
  end

  # GET /books/1
  def show
    render json: @book, include: %i[ authors subjects ]
  end

  # POST /books
  def create
    @book = Book.new(new_book_params)

    if @book.save
      render json: @book, include: %i[ authors subjects ], status: :created, location: @book
    else
      render json: @book.errors, status: :unprocessable_content
    end
  end

  # PATCH/PUT /books/1
  def update
    if @book.update(book_params)
      render json: @book, include: %i[ authors subjects ]
    else
      render json: @book.errors, status: :unprocessable_content
    end
  end

  # DELETE /books/1
  def destroy
    @book.destroy!
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_book
      @book = Book.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def book_params
      params.expect(book: [ :title, :description, :release_date, :total_pages ])
    end

    # author_name and subject_names are only accepted on create; they link the book to existing or new records.
    def new_book_params
      params.expect(book: [ :title, :description, :release_date, :total_pages, :author_name, subject_names: [] ])
    end
end

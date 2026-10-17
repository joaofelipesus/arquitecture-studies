class BooksController < ApplicationController
  wrap_parameters include: %i[ title description release_date total_pages author_name subject_names ]

  before_action :set_book, only: %i[ update destroy ]

  # GET /books
  def index
    @books = Book.includes(:authors, :subjects)
  end

  # GET /books/search?q=dune
  # GET /books/search?q=dune herbert
  # One search box over the title and the author names (see Book::Searchable), closest titles first.
  # Each book also carries "readers": how many users have it, in total and per status.
  def search
    @books = Book.search(params[:q]).includes(:authors, :subjects)
    @readers = UserBook.reader_counts_by_book(@books.map(&:id))

    render :index
  end

  # GET /books/1
  # Served from Rails.cache (Redis) when it's there, without touching the database; otherwise the book is loaded
  # and rendered, and the JSON cached. Book::ShowCache deletes the entry whenever the book changes.
  def show
    json = Rails.cache.fetch(Book.show_cache_key(params.expect(:id)), expires_in: 12.hours) do
      @book = Book.includes(:authors, :subjects).find(params.expect(:id))
      render_to_string(:show)
    end

    render json: json
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

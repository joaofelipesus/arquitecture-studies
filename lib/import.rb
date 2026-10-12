require "csv"

# Imports a catalog export: subjects.csv, authors.csv, books.csv, users.csv and user_books.csv.
#
# Records are written with insert_all for speed, which skips model validations and normalizations, so the
# rules of the models are applied here:
# - authors and subjects are matched by their squished name, merging the rows of the export that share a name;
# - books, users and user books keep their export ids, so the export's references can be used as they are;
# - books without pages are skipped, together with the user books that point to them;
# - user books have current_page clamped to the book's total pages, current_progress recalculated from it,
#   and started_at cleared when it is after finished_at; when a user has the same book more than once, the
#   first row is kept.
class Import
  class Error < StandardError; end

  BATCH_SIZE = 5_000

  STATUSES = {
    "WANT_TO_READ" => "want_to_read",
    "READING" => "reading",
    "FINISHED" => "finished",
    "STOPPED" => "stopped"
  }.freeze

  attr_reader :stats

  def initialize(dir, logger: Logger.new($stdout))
    @dir = Pathname(dir)
    @logger = logger
    @stats = Hash.new(0)
  end

  def call
    check_files!
    check_empty_tables!

    ActiveRecord::Base.transaction do
      @subject_ids = import_named(Subject, "subjects.csv", :subjects)
      @author_ids = import_named(Author, "authors.csv", :authors) { |row| { biography: row["bio"].presence } }
      @book_pages = import_books
      @user_ids = import_users
      import_user_books
    end

    [ Book, User, UserBook ].each { |model| model.connection.reset_pk_sequence!(model.table_name) }

    stats
  end

  private
    def check_files!
      missing = %w[subjects.csv authors.csv books.csv users.csv user_books.csv].reject { |file| @dir.join(file).file? }
      raise Error, "Missing #{missing.join(", ")} in #{@dir}" if missing.any?
    end

    # Books, users and user books keep the export ids, which could clash with records that already exist.
    def check_empty_tables!
      not_empty = [ Book, User, UserBook ].select(&:exists?)
      raise Error, "#{not_empty.map(&:table_name).join(", ")} must be empty to import" if not_empty.any?
    end

    def each_row(file, &block)
      CSV.foreach(@dir.join(file), headers: true, encoding: "UTF-8", &block)
    end

    # Imports a model with a unique name, merging the export rows with the same squished name (the first row wins,
    # but blank attributes are filled from the next ones), and reusing records that already exist with that name.
    # Returns a map of export id => record id.
    def import_named(model, file, stat)
      records = {}
      export_ids = Hash.new { |hash, name| hash[name] = [] }

      each_row(file) do |row|
        name = row["name"].to_s.squish
        if name.empty?
          @stats[:"#{stat}_skipped"] += 1
          next
        end

        attributes = { name: name, created_at: row["created_at"], updated_at: row["updated_at"] }
        attributes.merge!(yield(row)) if block_given?
        records[name] = records.key?(name) ? records[name].merge(attributes) { |_, old, new| old.nil? ? new : old } : attributes
        export_ids[name] << row["id"].to_i
      end

      records.values.each_slice(BATCH_SIZE) { |batch| model.insert_all(batch, unique_by: :name) }
      @stats[stat] = records.size
      @stats[:"#{stat}_merged"] = export_ids.values.sum(&:size) - records.size
      @logger.info "#{model.name.pluralize}: #{records.size} (#{@stats[:"#{stat}_merged"]} merged by name)"

      ids = {}
      records.keys.each_slice(BATCH_SIZE) do |names|
        model.where(name: names).pluck(:name, :id).each do |name, id|
          export_ids[name].each { |export_id| ids[export_id] = id }
        end
      end
      ids
    end

    # Returns a map of book id => total pages, used to check the user books.
    def import_books
      pages = {}

      each_row("books.csv").each_slice(BATCH_SIZE) do |rows|
        books = []
        author_books = []
        book_subjects = []

        rows.each do |row|
          id = row["id"].to_i
          total_pages = row["total_pages"].to_i
          if total_pages <= 0
            @stats[:books_skipped] += 1
            @logger.warn "Skipping book #{id} (#{row["title"]}): it has no pages"
            next
          end

          pages[id] = total_pages
          books << {
            id: id,
            title: row["title"],
            description: row["description"],
            release_date: row["published_date"],
            total_pages: total_pages,
            created_at: row["created_at"],
            updated_at: row["updated_at"]
          }
          author_books.concat(links(row["author_ids"], @author_ids).map { |author_id| { author_id: author_id, book_id: id } })
          book_subjects.concat(links(row["subject_ids"], @subject_ids).map { |subject_id| { book_id: id, subject_id: subject_id } })
        end

        Book.insert_all!(books) if books.any?
        AuthorBook.insert_all!(author_books) if author_books.any?
        BookSubject.insert_all!(book_subjects) if book_subjects.any?
        @stats[:books] += books.size
        @stats[:author_books] += author_books.size
        @stats[:book_subjects] += book_subjects.size
        @logger.info "Books: #{@stats[:books]}"
      end

      pages
    end

    # Maps a list of export ids like "12,57" to record ids, without repeating the ids of merged records.
    def links(export_ids, ids)
      export_ids.to_s.split(",").filter_map { |export_id| ids[export_id.to_i] }.uniq
    end

    def import_users
      ids = Set.new

      each_row("users.csv").each_slice(BATCH_SIZE) do |rows|
        users = rows.map { |row| { id: row["id"].to_i, username: row["username"].to_s.strip, bio: row["bio"].presence } }
        User.insert_all!(users)
        ids.merge(users.pluck(:id))
      end

      @stats[:users] = ids.size
      @logger.info "Users: #{ids.size}"
      ids
    end

    def import_user_books
      @user_book_pairs = Set.new

      each_row("user_books.csv").each_slice(BATCH_SIZE) do |rows|
        user_books = rows.filter_map { |row| user_book_attributes(row) }
        UserBook.insert_all!(user_books) if user_books.any?
        @stats[:user_books] += user_books.size
      end

      @logger.info "User books: #{@stats[:user_books]} (#{@stats[:user_books_skipped]} skipped, " \
        "#{@stats[:user_books_duplicated]} duplicated, #{@stats[:user_books_page_clamped]} with current_page clamped, #{@stats[:user_books_started_at_cleared]} with started_at cleared)"
    end

    def user_book_attributes(row)
      total_pages = @book_pages[row["book_id"].to_i]
      status = STATUSES[row["status"]]
      unless total_pages && @user_ids.include?(row["user_id"].to_i) && status
        @stats[:user_books_skipped] += 1
        @logger.warn "Skipping user book #{row["id"]}: unknown book, user or status"
        return
      end

      unless @user_book_pairs.add?([ row["user_id"].to_i, row["book_id"].to_i ])
        @stats[:user_books_duplicated] += 1
        @logger.warn "Skipping user book #{row["id"]}: the user already has the book"
        return
      end

      current_page = row["current_page"].to_i.clamp(0, nil)
      if current_page > total_pages
        current_page = total_pages
        @stats[:user_books_page_clamped] += 1
      end

      started_at = row["started_at"]
      finished_at = row["finished_at"]
      if started_at && finished_at && Date.parse(finished_at) < Date.parse(started_at)
        started_at = nil
        @stats[:user_books_started_at_cleared] += 1
      end

      {
        id: row["id"].to_i,
        user_id: row["user_id"].to_i,
        book_id: row["book_id"].to_i,
        status: status,
        started_at: started_at,
        finished_at: finished_at,
        current_page: current_page,
        current_progress: (current_page.to_d / total_pages * 100).round(2),
        created_at: row["created_at"],
        updated_at: row["updated_at"]
      }
    end
end

namespace :import do
  desc "Import the catalog CSVs (subjects, authors, books, users and user_books) from lib/tasks/data, or from DIR when given"
  task :catalog, [ :dir ] => :environment do |_, args|
    dir = Rails.root.join(args[:dir] || ENV["DIR"] || "lib/tasks/data")

    stats = Import.new(dir).call
    puts "Done: #{stats.sort.map { |key, value| "#{key}=#{value}" }.join(", ")}"
  rescue Import::Error => e
    abort e.message
  end
end

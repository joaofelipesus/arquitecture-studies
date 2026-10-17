class AddSearchableToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :searchable, :text
  end
end

class AddTotalPagesToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :total_pages, :integer, null: false
  end
end

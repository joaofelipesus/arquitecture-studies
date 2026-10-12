class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :title
      t.text :description
      t.date :release_date

      t.timestamps
    end
  end
end

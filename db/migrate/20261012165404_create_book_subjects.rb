class CreateBookSubjects < ActiveRecord::Migration[8.1]
  def change
    create_table :book_subjects do |t|
      t.references :book, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true

      t.timestamps
    end

    add_index :book_subjects, %i[book_id subject_id], unique: true
  end
end

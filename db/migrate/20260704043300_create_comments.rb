class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :pull_request, null: false, foreign_key: true
      t.string :file_path
      t.integer :line_number
      t.text :body

      t.timestamps
    end
  end
end

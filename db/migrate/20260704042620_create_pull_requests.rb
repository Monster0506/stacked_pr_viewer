class CreatePullRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :pull_requests do |t|
      t.references :repo_config, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :title, null: false
      t.string :author, null: false
      t.string :base_branch, null: false
      t.string :head_branch, null: false
      t.string :base_sha, null: false
      t.string :head_sha, null: false
      t.string :state, null: false

      t.timestamps
    end

    add_index :pull_requests, [ :repo_config_id, :number ], unique: true
  end
end

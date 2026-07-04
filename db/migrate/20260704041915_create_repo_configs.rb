class CreateRepoConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :repo_configs do |t|
      t.string :owner
      t.string :name
      t.string :access_token

      t.timestamps
    end
  end
end

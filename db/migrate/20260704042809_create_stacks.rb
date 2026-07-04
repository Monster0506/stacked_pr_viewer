class CreateStacks < ActiveRecord::Migration[8.1]
  def change
    create_table :stacks do |t|
      t.references :repo_config, null: false, foreign_key: true

      t.timestamps
    end
  end
end

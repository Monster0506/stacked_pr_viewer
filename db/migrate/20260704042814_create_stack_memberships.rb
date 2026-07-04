class CreateStackMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :stack_memberships do |t|
      t.references :stack, null: false, foreign_key: true
      t.references :pull_request, null: false, foreign_key: true, index: { unique: true }
      t.integer :position
      t.boolean :manual_override

      t.timestamps
    end
  end
end

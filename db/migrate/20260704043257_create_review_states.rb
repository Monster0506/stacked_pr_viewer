class CreateReviewStates < ActiveRecord::Migration[8.1]
  def change
    create_table :review_states do |t|
      t.references :user, null: false, foreign_key: true
      t.references :pull_request, null: false, foreign_key: true
      t.string :last_viewed_sha

      t.timestamps
    end

    add_index :review_states, [ :user_id, :pull_request_id ], unique: true
  end
end

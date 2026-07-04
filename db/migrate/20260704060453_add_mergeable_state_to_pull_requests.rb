class AddMergeableStateToPullRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :pull_requests, :mergeable_state, :string
  end
end

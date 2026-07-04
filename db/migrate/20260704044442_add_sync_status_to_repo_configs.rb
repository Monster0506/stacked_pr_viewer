class AddSyncStatusToRepoConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :repo_configs, :last_sync_failed_at, :datetime
    add_column :repo_configs, :last_sync_error, :string
  end
end

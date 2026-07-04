class SyncAllReposJob < ApplicationJob
  queue_as :default

  def perform
    RepoConfig.find_each { |repo| SyncRepoJob.perform_later(repo) }
  end
end

class SyncRepoJob < ApplicationJob
  queue_as :default

  def perform(repo_config)
    GithubClient.open_pull_requests(repo_config).each do |pr_data|
      pr = repo_config.pull_requests.find_or_initialize_by(number: pr_data[:number])
      pr.update!(
        title: pr_data[:title],
        author: pr_data[:author],
        base_branch: pr_data[:base_branch],
        head_branch: pr_data[:head_branch],
        base_sha: pr_data[:base_sha],
        head_sha: pr_data[:head_sha],
        state: pr_data[:state]
      )
    end
  end
end

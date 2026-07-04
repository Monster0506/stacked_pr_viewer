class SyncRepoJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :default

  def perform(repo_config)
    # Fetched fresh on every execution (including resumes) since a
    # completed step's in-memory result isn't preserved across a resume.
    pr_data = GithubClient.open_pull_requests(repo_config)

    step(:sync_pull_requests, start: 0) do |step|
      pr_data[step.cursor..].each do |data|
        sync_pull_request(repo_config, data)
        step.advance!
      end
    end

    step :detect_stacks do
      StackDetector.call(repo_config)
    end

    repo_config.update!(last_sync_failed_at: nil, last_sync_error: nil)
    Rails.event.notify("repo_sync.succeeded", repo_config_id: repo_config.id)
  rescue Octokit::Error => e
    repo_config.update!(last_sync_failed_at: Time.current, last_sync_error: e.message)
    Rails.event.notify("repo_sync.failed", repo_config_id: repo_config.id, error: e.message)
  ensure
    Turbo::StreamsChannel.broadcast_replace_to(
      repo_config,
      target: "stacks_for_repo_#{repo_config.id}",
      partial: "repo_configs/stacks",
      locals: { repo_config: repo_config.reload }
    )
  end

  private

  def sync_pull_request(repo_config, pr_data)
    pr = repo_config.pull_requests.find_or_initialize_by(number: pr_data[:number])
    pr.update!(
      title: pr_data[:title],
      author: pr_data[:author],
      base_branch: pr_data[:base_branch],
      head_branch: pr_data[:head_branch],
      base_sha: pr_data[:base_sha],
      head_sha: pr_data[:head_sha],
      state: pr_data[:state],
      mergeable_state: pr_data[:mergeable_state]
    )
  end
end

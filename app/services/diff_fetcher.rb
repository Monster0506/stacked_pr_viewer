class DiffFetcher
  def self.call(pull_request)
    client = GithubClient.for(pull_request.repo_config)
    client.compare(
      pull_request.repo_config.full_name,
      pull_request.base_sha,
      pull_request.head_sha,
      accept: "application/vnd.github.v3.diff"
    )
  end

  def self.cumulative(pull_requests)
    return nil if pull_requests.empty?

    first_pr = pull_requests.first
    last_pr = pull_requests.last
    client = GithubClient.for(first_pr.repo_config)
    client.compare(
      first_pr.repo_config.full_name,
      first_pr.base_sha,
      last_pr.head_sha,
      accept: "application/vnd.github.v3.diff"
    )
  end
end

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
end

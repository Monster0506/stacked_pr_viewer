class GithubClient
  def self.for(repo_config)
    Octokit::Client.new(access_token: repo_config.access_token)
  end

  def self.open_pull_requests(repo_config)
    client = GithubClient.for(repo_config)
    client.pull_requests(repo_config.full_name, state: "open").map do |pr|
      {
        number: pr.number,
        title: pr.title,
        author: pr.user.login,
        base_branch: pr.base.ref,
        base_sha: pr.base.sha,
        head_branch: pr.head.ref,
        head_sha: pr.head.sha,
        state: pr.state,
        mergeable_state: client.pull_request(repo_config.full_name, pr.number).mergeable_state
      }
    end
  end
end

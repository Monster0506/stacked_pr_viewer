require "test_helper"

class DiffFetcherTest < ActiveSupport::TestCase
  test "fetches the unified diff between base and head sha via GitHub compare API" do
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    pr = PullRequest.create!(repo_config: repo, number: 1, title: "t", author: "a", base_branch: "main", head_branch: "feat", base_sha: "aaa", head_sha: "bbb", state: "open")

    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/aaa...bbb")
      .with(headers: { "Accept" => "application/vnd.github.v3.diff" })
      .to_return(status: 200, body: "diff --git a/file.rb b/file.rb\n+added line\n")

    result = DiffFetcher.call(pr)

    assert_equal "diff --git a/file.rb b/file.rb\n+added line\n", result
  end
end

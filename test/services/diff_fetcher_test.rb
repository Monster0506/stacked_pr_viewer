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

  test "cumulative fetches the diff from the first PR's base to the last PR's head" do
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    pr1 = PullRequest.create!(repo_config: repo, number: 1, title: "t1", author: "a", base_branch: "main", head_branch: "stack-1", base_sha: "main_sha", head_sha: "stack1_sha", state: "open")
    pr2 = PullRequest.create!(repo_config: repo, number: 2, title: "t2", author: "a", base_branch: "stack-1", head_branch: "stack-2", base_sha: "stack1_sha", head_sha: "stack2_sha", state: "open")

    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/main_sha...stack2_sha")
      .with(headers: { "Accept" => "application/vnd.github.v3.diff" })
      .to_return(status: 200, body: "diff --git a/whole.rb b/whole.rb\n+everything\n")

    result = DiffFetcher.cumulative([ pr1, pr2 ])

    assert_equal "diff --git a/whole.rb b/whole.rb\n+everything\n", result
  end

  test "cumulative returns nil for an empty stack" do
    assert_nil DiffFetcher.cumulative([])
  end
end

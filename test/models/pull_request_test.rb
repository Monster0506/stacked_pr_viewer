require "test_helper"

class PullRequestTest < ActiveSupport::TestCase
  test "belongs to a repo_config and requires a number" do
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    pr = PullRequest.new(repo_config: repo, title: "x", author: "a", base_branch: "main", head_branch: "feat", base_sha: "a", head_sha: "b", state: "open")
    assert_not pr.valid?
    assert_includes pr.errors.attribute_names, :number

    pr.number = 1
    assert pr.valid?
  end

  test "uniqueness of number scoped to repo_config" do
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    PullRequest.create!(repo_config: repo, number: 1, title: "x", author: "a", base_branch: "main", head_branch: "feat", base_sha: "a", head_sha: "b", state: "open")
    dup = PullRequest.new(repo_config: repo, number: 1, title: "y", author: "a", base_branch: "main", head_branch: "feat2", base_sha: "a", head_sha: "c", state: "open")
    assert_not dup.valid?
  end
end

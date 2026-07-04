require "test_helper"

class ReviewStateTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "u@example.com", password: "password123")
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    @pr = PullRequest.create!(repo_config: repo, number: 1, title: "t", author: "a", base_branch: "main", head_branch: "feat", base_sha: "a", head_sha: "sha1", state: "open")
  end

  test "mark_viewed! records the PR's current head_sha" do
    ReviewState.mark_viewed!(user: @user, pull_request: @pr)
    state = ReviewState.find_by(user: @user, pull_request: @pr)
    assert_equal "sha1", state.last_viewed_sha
  end

  test "stale? is true once the PR's head_sha moves past what was viewed" do
    ReviewState.mark_viewed!(user: @user, pull_request: @pr)
    state = ReviewState.find_by(user: @user, pull_request: @pr)
    assert_not state.stale?

    @pr.update!(head_sha: "sha2")
    assert state.reload.stale?
  end
end

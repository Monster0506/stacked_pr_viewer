require "test_helper"

class ReviewStatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "u@example.com", password: "password123")
    sign_in_as(@user)

    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    @pr = PullRequest.create!(repo_config: repo, number: 1, title: "t", author: "a", base_branch: "main", head_branch: "feat", base_sha: "a", head_sha: "sha1", state: "open")
    stack = repo.stacks.create!
    stack.stack_memberships.create!(pull_request: @pr, position: 0)
  end

  test "marks the pull request as viewed by the current user at its current head_sha" do
    post review_states_url, params: { review_state: { pull_request_id: @pr.id } }

    state = ReviewState.find_by(user: @user, pull_request: @pr)
    assert_equal "sha1", state.last_viewed_sha
    assert_not state.stale?
    assert_response :redirect
  end
end

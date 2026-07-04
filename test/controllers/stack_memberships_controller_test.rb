require "test_helper"

class StackMembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "u@example.com", password: "password123")
    sign_in_as(@user)

    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    pr = PullRequest.create!(repo_config: repo, number: 1, title: "t", author: "a", base_branch: "main", head_branch: "feat", base_sha: "a", head_sha: "b", state: "open")
    stack = repo.stacks.create!
    @membership = stack.stack_memberships.create!(pull_request: pr, position: 0)
  end

  test "updating position sets manual_override" do
    patch stack_membership_url(@membership), params: { stack_membership: { position: 3 } }

    @membership.reload
    assert_equal 3, @membership.position
    assert @membership.manual_override
  end
end

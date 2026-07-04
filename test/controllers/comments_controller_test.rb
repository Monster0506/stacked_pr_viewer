require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "u@example.com", password: "password123")
    sign_in_as(@user)

    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    @pr = PullRequest.create!(repo_config: repo, number: 1, title: "t", author: "a", base_branch: "main", head_branch: "feat", base_sha: "a", head_sha: "b", state: "open")
    stack = repo.stacks.create!
    stack.stack_memberships.create!(pull_request: @pr, position: 0)
  end

  test "creates a comment owned by the current user" do
    assert_difference -> { Comment.count }, 1 do
      post comments_url, params: { comment: { pull_request_id: @pr.id, file_path: "file.rb", line_number: 3, body: "why is this needed?" } }
    end

    comment = Comment.last
    assert_equal @user, comment.user
    assert_equal @pr, comment.pull_request
    assert_equal "file.rb", comment.file_path
    assert_equal 3, comment.line_number
    assert_response :redirect
  end

  test "rejects a blank body" do
    assert_no_difference -> { Comment.count } do
      post comments_url, params: { comment: { pull_request_id: @pr.id, file_path: "file.rb", line_number: 3, body: "" } }
    end

    assert_response :unprocessable_entity
  end
end

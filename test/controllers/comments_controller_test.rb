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

  test "returns the created comment as JSON when requested" do
    post comments_url, params: { comment: { pull_request_id: @pr.id, file_path: "file.rb", line_number: 3, body: "why is this needed?" } }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "file.rb", body["file_path"]
    assert_equal 3, body["line_number"]
    assert_equal "why is this needed?", body["body"]
    assert_equal @user.email_address, body["author"]
    assert_equal Comment.last.id, body["id"]
    assert_nil body["parent_id"]
    assert_equal true, body["editable"]
  end

  test "creates a reply attached to a top-level comment" do
    top_level = Comment.create!(user: @user, pull_request: @pr, file_path: "file.rb", line_number: 3, body: "top level")

    assert_difference -> { Comment.count }, 1 do
      post comments_url, params: { comment: { pull_request_id: @pr.id, file_path: "file.rb", line_number: 3, body: "a reply", parent_id: top_level.id } }, as: :json
    end

    assert_response :created
    assert_equal top_level.id, JSON.parse(response.body)["parent_id"]
  end

  test "returns JSON errors for an invalid comment when requested" do
    post comments_url, params: { comment: { pull_request_id: @pr.id, file_path: "file.rb", line_number: 3, body: "" } }, as: :json

    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].present?
  end

  test "the owner can edit their comment's body" do
    comment = Comment.create!(user: @user, pull_request: @pr, file_path: "file.rb", line_number: 3, body: "original")

    patch comment_url(comment), params: { comment: { body: "edited" } }, as: :json

    assert_response :success
    assert_equal "edited", comment.reload.body
    assert_equal "edited", JSON.parse(response.body)["body"]
  end

  test "editing rejects a blank body" do
    comment = Comment.create!(user: @user, pull_request: @pr, file_path: "file.rb", line_number: 3, body: "original")

    patch comment_url(comment), params: { comment: { body: "" } }, as: :json

    assert_response :unprocessable_entity
    assert_equal "original", comment.reload.body
  end

  test "a user cannot edit another user's comment" do
    other_user = User.create!(email_address: "other@example.com", password: "password123")
    comment = Comment.create!(user: other_user, pull_request: @pr, file_path: "file.rb", line_number: 3, body: "original")

    patch comment_url(comment), params: { comment: { body: "hijacked" } }, as: :json

    assert_response :forbidden
    assert_equal "original", comment.reload.body
  end
end

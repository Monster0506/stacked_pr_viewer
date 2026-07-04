require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "requires file_path and body" do
    user = User.create!(email_address: "u@example.com", password: "password123")
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    pr = PullRequest.create!(repo_config: repo, number: 1, title: "t", author: "a", base_branch: "main", head_branch: "feat", base_sha: "a", head_sha: "b", state: "open")

    comment = Comment.new(user: user, pull_request: pr)
    assert_not comment.valid?
    assert_includes comment.errors.attribute_names, :file_path
    assert_includes comment.errors.attribute_names, :body
  end
end

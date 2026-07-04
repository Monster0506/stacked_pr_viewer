require "test_helper"

class StacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "u@example.com", password: "password123")
    sign_in_as(@user)

    @repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    @pr = PullRequest.create!(repo_config: @repo, number: 1, title: "Add feature", author: "octocat", base_branch: "main", head_branch: "feat", base_sha: "aaa", head_sha: "bbb", state: "open", mergeable_state: "dirty")
    @stack = @repo.stacks.create!
    @stack.stack_memberships.create!(pull_request: @pr, position: 0)
    @comment = Comment.create!(user: @user, pull_request: @pr, file_path: "file.rb", line_number: 1, body: "looks good")

    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/aaa...bbb")
      .to_return(status: 200, body: "diff --git a/file.rb b/file.rb\n+added line\n")
  end

  test "returns pull requests in stack order with diff, staleness, and comments" do
    get stack_url(@stack, format: :json)
    assert_response :success

    body = JSON.parse(response.body)
    pr_json = body["pull_requests"].first

    assert_equal @pr.id, pr_json["id"]
    assert_equal 1, pr_json["number"]
    assert_equal "Add feature", pr_json["title"]
    assert_equal "octocat", pr_json["author"]
    assert_includes pr_json["diff"], "added line"
    assert_equal true, pr_json["stale_for_current_user"]
    assert_equal true, pr_json["conflicted"]
    assert_includes body["cumulative_diff"], "added line"

    comment_json = pr_json["comments"].first
    assert_equal @comment.id, comment_json["id"]
    assert_nil comment_json["parent_id"]
    assert_equal "looks good", comment_json["body"]
    assert_equal @user.email_address, comment_json["author"]
    assert_equal true, comment_json["editable"]
  end
end

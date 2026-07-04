require "application_system_test_case"

class StackViewTest < ApplicationSystemTestCase
  test "visiting a stack renders at least one file diff" do
    user = User.create!(email_address: "u@example.com", password: "password123")
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    pr = PullRequest.create!(repo_config: repo, number: 1, title: "Add feature", author: "octocat", base_branch: "main", head_branch: "feat", base_sha: "aaa", head_sha: "bbb", state: "open")
    stack = repo.stacks.create!
    stack.stack_memberships.create!(pull_request: pr, position: 0)

    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/aaa...bbb")
      .to_return(status: 200, body: "diff --git a/file.rb b/file.rb\nindex 0000000..1111111 100644\n--- a/file.rb\n+++ b/file.rb\n@@ -1 +1,2 @@\n line one\n+added line\n")

    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123"
    click_button "Sign in"

    assert_current_path root_path

    visit stack_path(stack)

    assert_selector "#stack-diff-root", visible: :all
    assert_text "Add feature"
  end
end

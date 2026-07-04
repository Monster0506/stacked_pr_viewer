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

    Comment.create!(user: user, pull_request: pr, file_path: "file.rb", line_number: 1, body: "looks good")

    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123"
    click_button "Sign in"

    assert_current_path root_path

    visit stack_path(stack)

    assert_selector "#stack-diff-root", visible: :all
    assert_text "Add feature"
    assert_text "new changes"
    assert_text "looks good"
  end

  test "submitting the comment form adds a new comment" do
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

    click_diff_line_number
    assert_selector "form[data-role='comment-form']"
    page.execute_script("window.__noReloadMarker = true")

    fill_in "Add a comment", with: "why change this?"
    click_button "Comment"

    assert_current_path stack_path(stack)
    assert_text "why change this?"
    assert_equal 1, Comment.count
    assert page.evaluate_script("window.__noReloadMarker"), "expected the comment to be added without a full page reload"
  end

  test "replying to a comment adds a threaded reply" do
    user = User.create!(email_address: "u@example.com", password: "password123")
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    pr = PullRequest.create!(repo_config: repo, number: 1, title: "Add feature", author: "octocat", base_branch: "main", head_branch: "feat", base_sha: "aaa", head_sha: "bbb", state: "open")
    stack = repo.stacks.create!
    stack.stack_memberships.create!(pull_request: pr, position: 0)
    top_level = Comment.create!(user: user, pull_request: pr, file_path: "file.rb", line_number: 1, body: "looks good")

    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/aaa...bbb")
      .to_return(status: 200, body: "diff --git a/file.rb b/file.rb\nindex 0000000..1111111 100644\n--- a/file.rb\n+++ b/file.rb\n@@ -1 +1,2 @@\n line one\n+added line\n")

    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_current_path root_path

    visit stack_path(stack)
    assert_text "looks good"

    open_thread_actions_popup(top_level)
    click_button "Reply"

    fill_in "Write a reply", with: "thanks!"
    click_button "Reply"

    assert_text "thanks!"
    assert_equal 2, Comment.count
    reply = Comment.find_by(body: "thanks!")
    assert_equal top_level, reply.parent
  end

  test "editing your own comment updates its body" do
    user = User.create!(email_address: "u@example.com", password: "password123")
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    pr = PullRequest.create!(repo_config: repo, number: 1, title: "Add feature", author: "octocat", base_branch: "main", head_branch: "feat", base_sha: "aaa", head_sha: "bbb", state: "open")
    stack = repo.stacks.create!
    stack.stack_memberships.create!(pull_request: pr, position: 0)
    comment = Comment.create!(user: user, pull_request: pr, file_path: "file.rb", line_number: 1, body: "origianl typo")

    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/aaa...bbb")
      .to_return(status: 200, body: "diff --git a/file.rb b/file.rb\nindex 0000000..1111111 100644\n--- a/file.rb\n+++ b/file.rb\n@@ -1 +1,2 @@\n line one\n+added line\n")

    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_current_path root_path

    visit stack_path(stack)
    assert_text "origianl typo"

    open_thread_actions_popup(comment)
    click_button "Edit comment"
    find("input[type='text']").set("original, fixed")
    click_button "Save"

    assert_text "original, fixed"
    assert_no_text "origianl typo"
    assert_equal "original, fixed", comment.reload.body
  end

  test "a user cannot edit someone else's comment" do
    user = User.create!(email_address: "u@example.com", password: "password123")
    other_user = User.create!(email_address: "other@example.com", password: "password123")
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    pr = PullRequest.create!(repo_config: repo, number: 1, title: "Add feature", author: "octocat", base_branch: "main", head_branch: "feat", base_sha: "aaa", head_sha: "bbb", state: "open")
    stack = repo.stacks.create!
    stack.stack_memberships.create!(pull_request: pr, position: 0)
    comment = Comment.create!(user: other_user, pull_request: pr, file_path: "file.rb", line_number: 1, body: "someone else's comment")

    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/aaa...bbb")
      .to_return(status: 200, body: "diff --git a/file.rb b/file.rb\nindex 0000000..1111111 100644\n--- a/file.rb\n+++ b/file.rb\n@@ -1 +1,2 @@\n line one\n+added line\n")

    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_current_path root_path

    visit stack_path(stack)
    assert_text "someone else's comment"

    open_thread_actions_popup(comment)
    assert_no_button "Edit comment"
    assert_button "Reply"
  end

  test "deleting your own comment removes it, including its replies" do
    user = User.create!(email_address: "u@example.com", password: "password123")
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    pr = PullRequest.create!(repo_config: repo, number: 1, title: "Add feature", author: "octocat", base_branch: "main", head_branch: "feat", base_sha: "aaa", head_sha: "bbb", state: "open")
    stack = repo.stacks.create!
    stack.stack_memberships.create!(pull_request: pr, position: 0)
    comment = Comment.create!(user: user, pull_request: pr, file_path: "file.rb", line_number: 1, body: "delete me")
    Comment.create!(user: user, pull_request: pr, file_path: "file.rb", line_number: 1, body: "a reply to delete", parent: comment)

    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/aaa...bbb")
      .to_return(status: 200, body: "diff --git a/file.rb b/file.rb\nindex 0000000..1111111 100644\n--- a/file.rb\n+++ b/file.rb\n@@ -1 +1,2 @@\n line one\n+added line\n")

    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_current_path root_path

    visit stack_path(stack)
    assert_text "delete me"
    assert_text "a reply to delete"

    accept_confirm do
      open_thread_actions_popup(comment)
      click_button "Delete comment"
    end

    assert_no_text "delete me"
    assert_no_text "a reply to delete"
    assert_equal 0, Comment.count
  end

  test "marking a PR reviewed clears its stale badge" do
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
    assert_text "new changes"

    click_button "Mark reviewed"

    assert_current_path stack_path(stack)
    assert_no_text "new changes"
    assert ReviewState.find_by(user: user, pull_request: pr).stale? == false
  end

  test "a multi-PR stack renders a cumulative diff section" do
    user = User.create!(email_address: "u@example.com", password: "password123")
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    pr1 = PullRequest.create!(repo_config: repo, number: 1, title: "First", author: "octocat", base_branch: "main", head_branch: "stack-1", base_sha: "main_sha", head_sha: "stack1_sha", state: "open")
    pr2 = PullRequest.create!(repo_config: repo, number: 2, title: "Second", author: "octocat", base_branch: "stack-1", head_branch: "stack-2", base_sha: "stack1_sha", head_sha: "stack2_sha", state: "open")
    stack = repo.stacks.create!
    stack.stack_memberships.create!(pull_request: pr1, position: 0)
    stack.stack_memberships.create!(pull_request: pr2, position: 1)

    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/main_sha...stack1_sha")
      .to_return(status: 200, body: "diff --git a/one.rb b/one.rb\nindex 0000000..1111111 100644\n--- a/one.rb\n+++ b/one.rb\n@@ -1 +1,2 @@\n line one\n+first change\n")
    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/stack1_sha...stack2_sha")
      .to_return(status: 200, body: "diff --git a/two.rb b/two.rb\nindex 0000000..2222222 100644\n--- a/two.rb\n+++ b/two.rb\n@@ -1 +1,2 @@\n line one\n+second change\n")
    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/main_sha...stack2_sha")
      .to_return(status: 200, body: "diff --git a/one.rb b/one.rb\nindex 0000000..1111111 100644\n--- a/one.rb\n+++ b/one.rb\n@@ -1 +1,2 @@\n line one\n+first change\ndiff --git a/two.rb b/two.rb\nindex 0000000..2222222 100644\n--- a/two.rb\n+++ b/two.rb\n@@ -1 +1,2 @@\n line one\n+second change\n")

    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_current_path root_path

    visit stack_path(stack)

    assert_text "Cumulative diff (2 PRs)"
    assert_text "first change"
    assert_text "second change"
  end

  test "commenting on the cumulative diff attributes the comment to the top PR" do
    user = User.create!(email_address: "u@example.com", password: "password123")
    repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    pr1 = PullRequest.create!(repo_config: repo, number: 1, title: "First", author: "octocat", base_branch: "main", head_branch: "stack-1", base_sha: "main_sha", head_sha: "stack1_sha", state: "open")
    pr2 = PullRequest.create!(repo_config: repo, number: 2, title: "Second", author: "octocat", base_branch: "stack-1", head_branch: "stack-2", base_sha: "stack1_sha", head_sha: "stack2_sha", state: "open")
    stack = repo.stacks.create!
    stack.stack_memberships.create!(pull_request: pr1, position: 0)
    stack.stack_memberships.create!(pull_request: pr2, position: 1)

    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/main_sha...stack1_sha")
      .to_return(status: 200, body: "diff --git a/one.rb b/one.rb\nindex 0000000..1111111 100644\n--- a/one.rb\n+++ b/one.rb\n@@ -1 +1,2 @@\n line one\n+first change\n")
    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/stack1_sha...stack2_sha")
      .to_return(status: 200, body: "diff --git a/two.rb b/two.rb\nindex 0000000..2222222 100644\n--- a/two.rb\n+++ b/two.rb\n@@ -1 +1,2 @@\n line one\n+second change\n")
    stub_request(:get, "https://api.github.com/repos/acme/widgets/compare/main_sha...stack2_sha")
      .to_return(status: 200, body: "diff --git a/one.rb b/one.rb\nindex 0000000..1111111 100644\n--- a/one.rb\n+++ b/one.rb\n@@ -1 +1,2 @@\n line one\n+first change\ndiff --git a/two.rb b/two.rb\nindex 0000000..2222222 100644\n--- a/two.rb\n+++ b/two.rb\n@@ -1 +1,2 @@\n line one\n+second change\n")

    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_current_path root_path

    visit stack_path(stack)
    assert_text "Cumulative diff (2 PRs)"

    click_diff_line_number
    assert_selector "form[data-role='comment-form']"

    fill_in "Add a comment", with: "comment from the cumulative view"
    click_button "Comment"

    assert_current_path stack_path(stack)
    assert_text "comment from the cumulative view"
    assert_equal pr2, Comment.sole.pull_request
  end

  private

  def click_diff_line_number
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        clicked = page.evaluate_script(<<~JS)
          (() => {
            const numberEl = Array.from(document.querySelectorAll("*"))
              .filter((el) => el.shadowRoot)
              .flatMap((el) => Array.from(el.shadowRoot.querySelectorAll("[data-column-number]")))[0];
            if (numberEl) { numberEl.click(); return true; }
            return false;
          })()
        JS
        break if clicked
        sleep 0.1
      end
    end
  end

  # Clicks the "..." button that @pierre/diffs' own blank gutter cell hosts
  # for this comment thread (see wireThreadActionButtons), opening its
  # actions popup. The button lives in the diff's shadow DOM, not in the
  # light-DOM comment row, so it's found and clicked via JS.
  def open_thread_actions_popup(comment)
    clicked = page.evaluate_script(<<~JS)
      (() => {
        const containers = Array.from(document.querySelectorAll("*")).filter((el) => el.shadowRoot);
        for (const fileContainer of containers) {
          const button = fileContainer.shadowRoot.querySelector("[data-role='thread-actions-button'][data-comment-thread='#{comment.id}']");
          if (button) { button.click(); return true; }
        }
        return false;
      })()
    JS
    raise "thread actions button not found for comment #{comment.id}" unless clicked
    find("[data-role='thread-actions-popup']", visible: :all)
  end
end

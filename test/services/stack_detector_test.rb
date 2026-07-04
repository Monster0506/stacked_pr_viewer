require "test_helper"

class StackDetectorTest < ActiveSupport::TestCase
  setup do
    @repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
  end

  def make_pr(number:, base:, head:)
    PullRequest.create!(
      repo_config: @repo, number: number, title: "PR #{number}", author: "a",
      base_branch: base, head_branch: head, base_sha: "s#{number}a", head_sha: "s#{number}b", state: "open"
    )
  end

  test "groups a simple three-PR chain into one ordered stack" do
    pr1 = make_pr(number: 1, base: "main", head: "feat-a")
    pr2 = make_pr(number: 2, base: "feat-a", head: "feat-b")
    pr3 = make_pr(number: 3, base: "feat-b", head: "feat-c")

    StackDetector.call(@repo)

    stack = Stack.sole
    ordered_prs = stack.stack_memberships.order(:position).map(&:pull_request)
    assert_equal [pr1, pr2, pr3], ordered_prs
  end

  test "independent PRs (base == main) each get their own single-PR stack" do
    make_pr(number: 1, base: "main", head: "feat-a")
    make_pr(number: 2, base: "main", head: "feat-b")

    StackDetector.call(@repo)

    assert_equal 2, Stack.count
    assert_equal [1, 1], Stack.all.map { |s| s.stack_memberships.count }
  end

  test "orphaned PR whose base branch matches no other PR's head still gets its own stack" do
    make_pr(number: 1, base: "some-deleted-branch", head: "feat-a")

    StackDetector.call(@repo)

    assert_equal 1, Stack.count
    assert_equal 1, Stack.sole.stack_memberships.count
  end

  test "re-running detection preserves a manual override instead of re-grouping" do
    pr1 = make_pr(number: 1, base: "main", head: "feat-a")
    pr2 = make_pr(number: 2, base: "feat-a", head: "feat-b")
    StackDetector.call(@repo)

    stack = Stack.sole
    membership = stack.stack_memberships.find_by(pull_request: pr2)
    membership.update!(manual_override: true, position: 5)

    StackDetector.call(@repo)

    membership.reload
    assert_equal 5, membership.position
    assert membership.manual_override
  end
end

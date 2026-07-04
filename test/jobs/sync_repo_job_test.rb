require "test_helper"
require "active_job/continuation/test_helper"

class SyncRepoJobTest < ActiveJob::TestCase
  include ActiveJob::Continuation::TestHelper

  setup do
    @repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
  end

  test "creates a PullRequest for each open PR from GitHub" do
    stub_request(:get, "https://api.github.com/repos/acme/widgets/pulls?state=open")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [
          { number: 1, title: "A", user: { login: "octocat" }, base: { ref: "main", sha: "a1" }, head: { ref: "feat-a", sha: "b1" }, state: "open" }
        ].to_json
      )
    stub_request(:get, "https://api.github.com/repos/acme/widgets/pulls/1")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { number: 1, mergeable_state: "clean" }.to_json)

    assert_difference("PullRequest.count", 1) do
      SyncRepoJob.perform_now(@repo)
    end

    pr = PullRequest.last
    assert_equal 1, pr.number
    assert_equal "octocat", pr.author
    assert_equal "clean", pr.mergeable_state
  end

  test "updates an existing PullRequest instead of duplicating it" do
    PullRequest.create!(repo_config: @repo, number: 1, title: "old", author: "octocat", base_branch: "main", head_branch: "feat-a", base_sha: "a0", head_sha: "b0", state: "open")

    stub_request(:get, "https://api.github.com/repos/acme/widgets/pulls?state=open")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [
          { number: 1, title: "new title", user: { login: "octocat" }, base: { ref: "main", sha: "a1" }, head: { ref: "feat-a", sha: "b1" }, state: "open" }
        ].to_json
      )
    stub_request(:get, "https://api.github.com/repos/acme/widgets/pulls/1")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { number: 1, mergeable_state: "clean" }.to_json)

    assert_no_difference("PullRequest.count") do
      SyncRepoJob.perform_now(@repo)
    end

    assert_equal "new title", PullRequest.last.title
  end

  test "runs stack detection after syncing PRs" do
    stub_request(:get, "https://api.github.com/repos/acme/widgets/pulls?state=open")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [
          { number: 1, title: "A", user: { login: "octocat" }, base: { ref: "main", sha: "a1" }, head: { ref: "feat-a", sha: "b1" }, state: "open" }
        ].to_json
      )
    stub_request(:get, "https://api.github.com/repos/acme/widgets/pulls/1")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { number: 1, mergeable_state: "clean" }.to_json)

    SyncRepoJob.perform_now(@repo)

    assert_equal 1, Stack.count
  end

  test "records a failure on the repo config instead of raising, when GitHub API call fails" do
    stub_request(:get, "https://api.github.com/repos/acme/widgets/pulls?state=open")
      .to_return(status: 401, body: '{"message":"Bad credentials"}')

    SyncRepoJob.perform_now(@repo)

    @repo.reload
    assert @repo.last_sync_failed_at.present?
    assert_includes @repo.last_sync_error, "Bad credentials"
  end

  test "resumes the per-PR sync from where it left off after an interruption" do
    stub_request(:get, "https://api.github.com/repos/acme/widgets/pulls?state=open")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [
          { number: 1, title: "A", user: { login: "octocat" }, base: { ref: "main", sha: "a1" }, head: { ref: "feat-a", sha: "b1" }, state: "open" },
          { number: 2, title: "B", user: { login: "octocat" }, base: { ref: "main", sha: "a2" }, head: { ref: "feat-b", sha: "b2" }, state: "open" }
        ].to_json
      )
    stub_request(:get, "https://api.github.com/repos/acme/widgets/pulls/1")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { number: 1, mergeable_state: "clean" }.to_json)
    stub_request(:get, "https://api.github.com/repos/acme/widgets/pulls/2")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { number: 2, mergeable_state: "clean" }.to_json)

    SyncRepoJob.perform_later(@repo)
    interrupt_job_during_step(SyncRepoJob, :sync_pull_requests, cursor: 1) { perform_enqueued_jobs }

    assert_equal [ 1 ], PullRequest.pluck(:number)

    perform_enqueued_jobs

    assert_equal [ 1, 2 ], PullRequest.order(:number).pluck(:number)
  end
end

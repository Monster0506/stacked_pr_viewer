require "test_helper"

class GithubClientTest < ActiveSupport::TestCase
  setup do
    @repo = RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
  end

  test "open_pull_requests maps GitHub API response to plain hashes" do
    stub_request(:get, "https://api.github.com/repos/acme/widgets/pulls?state=open")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [
          {
            number: 42,
            title: "Add feature",
            user: { login: "octocat" },
            base: { ref: "main", sha: "aaa111" },
            head: { ref: "feature-a", sha: "bbb222" },
            state: "open"
          }
        ].to_json
      )

    stub_request(:get, "https://api.github.com/repos/acme/widgets/pulls/42")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { number: 42, mergeable_state: "dirty" }.to_json
      )

    result = GithubClient.open_pull_requests(@repo)

    assert_equal 1, result.length
    assert_equal({
      number: 42,
      title: "Add feature",
      author: "octocat",
      base_branch: "main",
      base_sha: "aaa111",
      head_branch: "feature-a",
      head_sha: "bbb222",
      state: "open",
      mergeable_state: "dirty"
    }, result.first)
  end
end

require "test_helper"

class RepoConfigsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "test@example.com", password: "password123")
    sign_in_as(@user)
  end

  test "creates a repo config" do
    assert_difference("RepoConfig.count", 1) do
      post repo_configs_url, params: { repo_config: { owner: "acme", name: "widgets", access_token: "ghp_x" } }
    end
    assert_redirected_to repo_configs_url
  end

  test "lists repo configs" do
    RepoConfig.create!(owner: "acme", name: "widgets", access_token: "ghp_x")
    get repo_configs_url
    assert_response :success
    assert_select "body", text: /acme\/widgets/
  end
end

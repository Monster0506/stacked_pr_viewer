require "test_helper"

class RepoConfigTest < ActiveSupport::TestCase
  test "full_name combines owner and name" do
    repo = RepoConfig.new(owner: "acme", name: "widgets", access_token: "ghp_x")
    assert_equal "acme/widgets", repo.full_name
  end

  test "requires owner, name, and access_token" do
    repo = RepoConfig.new
    assert_not repo.valid?
    assert_includes repo.errors.attribute_names, :owner
    assert_includes repo.errors.attribute_names, :name
    assert_includes repo.errors.attribute_names, :access_token
  end
end

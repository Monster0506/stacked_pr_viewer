class PullRequest < ApplicationRecord
  belongs_to :repo_config
  has_one :stack_membership, dependent: :destroy

  validates :number, presence: true, uniqueness: { scope: :repo_config_id }
  validates :title, :author, :base_branch, :head_branch, :base_sha, :head_sha, :state, presence: true
end

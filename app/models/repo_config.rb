class RepoConfig < ApplicationRecord
  encrypts :access_token

  has_many :pull_requests, dependent: :destroy

  validates :owner, presence: true
  validates :name, presence: true
  validates :access_token, presence: true

  def full_name
    "#{owner}/#{name}"
  end
end

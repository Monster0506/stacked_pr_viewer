class Stack < ApplicationRecord
  belongs_to :repo_config
  has_many :stack_memberships, -> { order(:position) }, dependent: :destroy
  has_many :pull_requests, through: :stack_memberships
end

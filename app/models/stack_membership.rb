class StackMembership < ApplicationRecord
  belongs_to :stack
  belongs_to :pull_request
end

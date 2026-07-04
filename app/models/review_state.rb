class ReviewState < ApplicationRecord
  belongs_to :user
  belongs_to :pull_request

  def self.mark_viewed!(user:, pull_request:)
    state = find_or_initialize_by(user: user, pull_request: pull_request)
    state.update!(last_viewed_sha: pull_request.head_sha)
    state
  end

  def stale?
    last_viewed_sha != pull_request.head_sha
  end
end

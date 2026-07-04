class ReviewStatesController < ApplicationController
  def create
    pull_request = PullRequest.find(params.require(:review_state)[:pull_request_id])
    ReviewState.mark_viewed!(user: Current.user, pull_request: pull_request)

    redirect_to stack_path(pull_request.stack_membership.stack)
  end
end

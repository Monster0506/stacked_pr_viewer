class StacksController < ApplicationController
  def show
    stack = Stack.find(params[:id])
    pull_requests = stack.stack_memberships.order(:position).includes(pull_request: :comments).map(&:pull_request)

    render json: {
      pull_requests: pull_requests.map { |pr| pull_request_json(pr) }
    }
  end

  private

  def pull_request_json(pr)
    review_state = ReviewState.find_by(user: Current.user, pull_request: pr)

    {
      number: pr.number,
      title: pr.title,
      author: pr.author,
      diff: DiffFetcher.call(pr),
      stale_for_current_user: review_state.nil? || review_state.stale?,
      comments: pr.comments.map { |c| { file_path: c.file_path, line_number: c.line_number, body: c.body, author: c.user.email_address } }
    }
  end
end

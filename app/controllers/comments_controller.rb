class CommentsController < ApplicationController
  def create
    pull_request = PullRequest.find(comment_params[:pull_request_id])
    comment = pull_request.comments.build(comment_params.except(:pull_request_id))
    comment.user = Current.user

    if comment.save
      redirect_to stack_path(pull_request.stack_membership.stack)
    else
      render plain: comment.errors.full_messages.to_sentence, status: :unprocessable_entity
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:pull_request_id, :file_path, :line_number, :body)
  end
end

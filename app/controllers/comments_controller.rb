class CommentsController < ApplicationController
  def create
    pull_request = PullRequest.find(comment_params[:pull_request_id])
    comment = pull_request.comments.build(comment_params.except(:pull_request_id))
    comment.user = Current.user

    if comment.save
      respond_to do |format|
        format.html { redirect_to stack_path(pull_request.stack_membership.stack) }
        format.json { render json: comment_json(comment), status: :created }
      end
    else
      respond_to do |format|
        format.html { render plain: comment.errors.full_messages.to_sentence, status: :unprocessable_entity }
        format.json { render json: { errors: comment.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:pull_request_id, :file_path, :line_number, :body)
  end

  def comment_json(comment)
    { file_path: comment.file_path, line_number: comment.line_number, body: comment.body, author: comment.user.email_address }
  end
end

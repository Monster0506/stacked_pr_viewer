class StackMembershipsController < ApplicationController
  def update
    membership = StackMembership.find(params[:id])
    membership.update!(position: params.dig(:stack_membership, :position), manual_override: true)
    redirect_to stack_path(membership.stack)
  end
end

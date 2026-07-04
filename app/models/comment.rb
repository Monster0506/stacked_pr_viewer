class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :pull_request
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  validates :file_path, presence: true
  validates :body, presence: true
  validate :parent_must_not_itself_be_a_reply

  private

  def parent_must_not_itself_be_a_reply
    errors.add(:parent, "can't be a reply to a reply") if parent&.parent_id.present?
  end
end

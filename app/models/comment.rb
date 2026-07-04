class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :pull_request

  validates :file_path, presence: true
  validates :body, presence: true
end

class RepoConfigsController < ApplicationController
  def index
    @repo_configs = RepoConfig.all
  end

  def new
    @repo_config = RepoConfig.new
  end

  def create
    @repo_config = RepoConfig.new(repo_config_params)
    if @repo_config.save
      redirect_to repo_configs_path, notice: "Repo added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def repo_config_params
    params.require(:repo_config).permit(:owner, :name, :access_token)
  end
end

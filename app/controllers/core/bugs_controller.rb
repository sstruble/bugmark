module Core
  class BugsController < ApplicationController

    layout 'core'

    # repo_id (optional)
    def index
      if repo_id = params["repo_id"]&.to_i
        @repo = Repo.find(repo_id)
        @bugs = Bug.where(repo_id: repo_id)
      else
        @repo = nil
        @bugs = Bug.all
      end
    end

    def show
      @bug = Bug.find(params["id"])
    end
  end
end

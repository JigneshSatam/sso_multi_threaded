class ApplicationController < ActionController::Base
  # protect_from_forgery with: :exception
  # after_action :disconnect_db

  def disconnect_db
    ActiveRecord::Base.connection_pool.disconnect!
  end
end

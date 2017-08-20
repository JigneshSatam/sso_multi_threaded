class ApplicationController < ActionController::Base
  # protect_from_forgery with: :exception
  # after_action :disconnect_db

  def disconnect_db
    ActiveRecord::Base.connection_pool.disconnect!
  end

  def after_login_path
    redirect_to current_user
  end

  def unauthenticated
    redirect_to root_url
  end
end

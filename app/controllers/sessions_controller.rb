class SessionsController < ApplicationController
  def create
    if logged_in?
      if params[:session][:redirect_to].present?
        app_url =  params[:session][:redirect_to] + "/dashboard"
        redirect_to generate_url(app_url, {token: jwt_token(current_user)}), status: 303
      else
        redirect_to current_user
      end
    end
    user = User.find_by(email: params[:session][:email].downcase)
    if user && user.authenticate(params[:session][:password])
      log_in(user)
      params[:session][:remember_me] == '1' ? remember(user) : forget(user)
      if params[:session][:redirect_to].present?
        app_url =  params[:session][:redirect_to] + "/dashboard"
        redirect_to generate_url(app_url, {token: jwt_token(user)}), status: 303
      else
        redirect_to user
      end
      # response.headers["Authorization"] = "Bearer #{jwt_token}"
      # request.headers["Authorization"] = "Bearer #{jwt_token}"
      # headers["Authorization"] = "Bearer #{jwt_token}"
      # debugger
    else
      flash[:danger] = 'Invalid email/password combination'
      redirect_to :back
    end
  end

  def destroy
    log_out if logged_in?
    redirect_to root_url
  end

  def new
  end
end

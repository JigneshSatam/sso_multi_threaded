class UsersController < ApplicationController
  before_filter :check_login, only: [:new]
  def show
    @user = User.find(params[:id])
  end

  def new
    if logged_in?
      if params[:session][:redirect_to].present?
        app_url =  params[:session][:redirect_to] + "/dashboard"
        redirect_to generate_url(app_url, {token: jwt_token(current_user)}), status: 303
      else
        redirect_to current_user
      end
    end
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      log_in @user
      remember @user
      flash[:success] = "Welcome to the SSO!!!"
      redirect_to @user
    else
      render 'new'
    end
  end

  private

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end

    def check_login
      if logged_in?
        if params[:app].present?
          app_url =  params[:app]
          redirect_to generate_url(app_url, {token: jwt_token(current_user)}), status: 303 and return
        else
          redirect_to current_user and return
        end
      end
    end
end

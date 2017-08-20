class UsersController < ApplicationController
  skip_before_action :check_authentication, only: [:new, :create]
  def show
    begin
      logger.debug "@@@@@@@@@@ SHOW before ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
      @user = current_user
      logger.debug "@@@@@@@@@@ SHOW middle ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
    rescue Exception => e
    ensure
      logger.debug "@@@@@@@@@@ Thread in SHOW ENSURE @@@@@@@@@@@@@@@@"
      User.connection.close
      logger.debug "@@@@@@@@@@ SHOW ENSURE ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
    end
      # puts "@@@@@@@@@@   Active connections show ==> #{ActiveRecord::Base.connection_pool.size} @@@@@@@@@@@@@@@@"
        # puts "@@@@@@@@@@   Active connections show ==> #{ActiveRecord::Base.connection_pool.size} @@@@@@@@@@@@@@@@"
    # begin
    #   puts "sessions controller | create method | BEGIN"
    #   # main_thread_conn = ActiveRecord::Base.connection_pool.checkout
    #   # main_thread_conn.raw_connection
    #   # debugger
    #   puts "@@@@@@@@@@   Thread is sleeping CREATE @@@@@@@@@@@@@@@@"
    #   ActiveRecord::Base.connection_pool.with_connection do
    #     @user = User.find(params[:id])
    #     puts "@@@@@@@@@@   Thread is sleeping CREATE @@@@@@@@@@@@@@@@"
    #     # sleep(10)
    #   end
    # rescue Exception => e
    #   puts "sessions controller | create method | #{e}"
    #   ActiveRecord::Base.connection_pool.disconnect!
    #   # ActiveRecord::Base.connection_pool.checkin(main_thread_conn)
    #   # ActiveRecord::Base.connection_pool.clear_reloadable_connections!
    #   # ActiveRecord::Base.clear_active_connections!
    #   # ActiveRecord::Base.connection.close
    #   # retry
    # ensure
    #   puts "sessions controller | create method | in ensure block"
    #   ActiveRecord::Base.connection_pool.disconnect!
    #   # ActiveRecord::Base.connection_pool.checkin(main_thread_conn)
    #   # ActiveRecord::Base.connection_pool.clear_reloadable_connections!
    #   # ActiveRecord::Base.clear_active_connections!
    #   # ActiveRecord::Base.connection.close
    # end
  end

  def new
    if current_user
      redirect_to current_user
    else
      @user = User.new
    end
  end

  def create
    @user = User.new(user_params)
    begin
      logger.debug "@@@@@@@@@@ SHOW before ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
      is_user_saved = @user.save
      logger.debug "@@@@@@@@@@ SHOW middle ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
    rescue Exception => e
    ensure
      logger.debug "@@@@@@@@@@ Thread in SHOW ENSURE @@@@@@@@@@@@@@@@"
      User.connection.close
      logger.debug "@@@@@@@@@@ SHOW ENSURE ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
    end
    if is_user_saved
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
end

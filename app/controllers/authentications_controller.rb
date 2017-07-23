class AuthenticationsController < ApplicationController
  def login
    # debugger
    user = nil
    begin
      # puts "sessions controller | create method | BEGIN"
      logger.debug "@@@@@@@@@@ CREATE before ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
      # main_thread_conn = ActiveRecord::Base.connection_pool.checkout
      # debugger
      # main_thread_conn.raw_connection
      user = User.find_by(email: params[:session][:email].downcase)
      logger.debug "@@@@@@@@@@ CREATE middle==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
      # sleep(20)
      # debugger
      # puts "@@@@@@@@@@   Active connections CREATE ==> #{ActiveRecord::Base.connection_pool.connections.size} @@@@@@@@@@@@@@@@"
      # puts "@@@@@@@@@@   Waiting connections CREATE ==> #{ActiveRecord::Base.connection_pool.num_waiting_in_queue} @@@@@@@@@@@@@@@@"
      # user = User.find_by(email: params[:session][:email].downcase)
      # puts "@@@@@@@@@@   Thread is sleeping CREATE @@@@@@@@@@@@@@@@"
      # ct = Thread.new do
      #   puts "@@@@@@@@@@ CREATE before ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
      #   user = User.find_by(email: params[:session][:email].downcase)
      #   puts "@@@@@@@@@@ CREATE middle==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
      #   User.connection.close
      #   # User.connection_pool.with_connection do
      #   # end
      #   puts "@@@@@@@@@@ CREATE after ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
      # end
      # ct.join

      # puts "@@@@@@@@@@ CREATE before ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
      # ActiveRecord::Base.connection_pool.with_connection do
      #   # debugger
      #   puts "@@@@@@@@@@ CREATE middle ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
      #   user = User.find_by(email: params[:session][:email].downcase)
      #   # puts "@@@@@@@@@@   Thread is sleeping CREATE @@@@@@@@@@@@@@@@"
      #   # sleep(10)
      # end
      # puts "@@@@@@@@@@ CREATE after ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
    rescue Exception => e
      # puts "sessions controller | create method | #{e}"
      # ActiveRecord::Base.connection_pool.disconnect!
      # ActiveRecord::Base.connection_pool.checkin(main_thread_conn)
      # ActiveRecord::Base.connection_pool.clear_reloadable_connections!
      # ActiveRecord::Base.clear_active_connections!
      # ActiveRecord::Base.connection.close
      # retry
    ensure
      logger.debug "@@@@@@@@@@ Thread in CREATE ENSURE @@@@@@@@@@@@@@@@"
      # User.connection_pool.release_connection
      User.connection.close
      # ActiveRecord::Base.connection_pool.checkin(main_thread_conn)
      logger.debug "@@@@@@@@@@ CREATE ENSURE ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
      # puts "@@@@@@@@@@ sessions controller | create method | in ensure block @@@@@@@@@@"
      # ActiveRecord::Base.connection_pool.release_connection
      # ActiveRecord::Base.connection_pool.disconnect!
      # puts "@@@@@@@@@@   Active connections CREATE ==> #{ActiveRecord::Base.connection_pool.connections.size} @@@@@@@@@@@@@@@@"
      #   puts "@@@@@@@@@@   Waiting connections CREATE ==> #{ActiveRecord::Base.connection_pool.num_waiting_in_queue} @@@@@@@@@@@@@@@@"
      # ActiveRecord::Base.connection_pool.clear_reloadable_connections!
      # ActiveRecord::Base.clear_active_connections!
      # ActiveRecord::Base.connection.close
    end
    # debugger
    if user && user.authenticate(params[:session][:password])
      log_in(user)
      params[:session][:remember_me] == '1' ? remember(user) : forget(user)
      if params[:session][:redirect_to].present?
        app_url =  params[:session][:redirect_to]
        respond_to do |format|
         format.html { redirect_to generate_url(app_url, {token: jwt_token(user)}), status: 303}
         format.json { nil }
        end
      else
        respond_to do |format|
         format.html { redirect_to user }
         format.json { render json: "#{user.id}\t\n" }
        end
      end
      # response.headers["Authorization"] = "Bearer #{jwt_token}"
      # request.headers["Authorization"] = "Bearer #{jwt_token}"
      # headers["Authorization"] = "Bearer #{jwt_token}"
      # debugger
    else
      flash[:danger] = 'Invalid email/password combination'
      redirect_to root_url
    end
  end

  def logout
    # debugger
    logger.debug "#{'$'*10} destroy started #{'$'*10}"
    # sleep(10)
    log_out if logged_in?
    logger.debug "#{'$'*10} destroy ended #{'$'*10}"
    redirect_to root_url
  end
end

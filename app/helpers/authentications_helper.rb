module AuthenticationsHelper
  module ClassMethods

  end

  module InstanceMethods
    def log_in(user)
      session[:user_id] = user.id
    end

    # Remembers a user in a persistent session.
    def remember(user)
      user.remember
      cookies.permanent.signed[:user_id] = user.id
      cookies.permanent[:remember_token] = user.remember_token
    end

    def current_user
      return @current_user if !@current_user.nil?
      if (user_id = session[:user_id])
        begin
          # main_thread_conn = ActiveRecord::Base.connection_pool.checkout
          # main_thread_conn.raw_connection
          # puts "@@@@@@@@@@   Active connections CURRENT_USER ==> #{ActiveRecord::Base.connection_pool.connections.size} @@@@@@@@@@@@@@@@"
          # puts "@@@@@@@@@@   Waiting connections CURRENT_USER ==> #{ActiveRecord::Base.connection_pool.num_waiting_in_queue} @@@@@@@@@@@@@@@@"
          # sleep(20)
          # @current_user ||= User.find_by(id: user_id)
          # puts "@@@@@@@@@@ CURRENT_USER before ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          # ActiveRecord::Base.connection_pool.with_connection do
          # #   puts "@@@@@@@@@@   Thread is sleeping CURRENT_USER @@@@@@@@@@@@@@@@"
          # #   puts "@@@@@@@@@@   Active connections CURRENT_USER ==> #{ActiveRecord::Base.connection_pool.connections.size} @@@@@@@@@@@@@@@@"
          #   # puts "@@@@@@@@@@   Waiting connections CURRENT_USER ==> #{ActiveRecord::Base.connection_pool.num_waiting_in_queue} @@@@@@@@@@@@@@@@"
          #   puts "@@@@@@@@@@ CURRENT_USER middle ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          #   sleep(20)
          #   @current_user ||= User.find_by(id: user_id)
          # end
          # puts "@@@@@@@@@@ CURRENT_USER after ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"

          logger.debug "@@@@@@@@@@ CURRENT_USER before ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          @current_user ||= User.find_by(id: user_id)
          logger.debug "@@@@@@@@@@ CURRENT_USER middle ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          # sleep(20)
          # ts = Thread.new do
          #   puts "@@@@@@@@@@ CURRENT_USER before ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          #   @current_user ||= User.find_by(id: user_id)
          #   puts "@@@@@@@@@@ CURRENT_USER middle ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          #   sleep(20)
          #   # User.connection_pool.with_connection do
          #   # end
          #   User.connection.close
          #   puts "@@@@@@@@@@ CURRENT_USER after ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          # end
          # ts.join
        rescue Exception => e
          logger.debug "@@@@@@@@@@ Thread is sleeping RESCUE #{e} @@@@@@@@@@@@@@@@"
          # ActiveRecord::Base.connection_pool.disconnect!
          # ActiveRecord::Base.connection_pool.clear_reloadable_connections!
          # ActiveRecord::Base.clear_active_connections!
          ActiveRecord::Base.connection.close
          retry
        ensure
          logger.debug "@@@@@@@@@@ Thread in CURRENT_USER ENSURE @@@@@@@@@@@@@@@@"
          User.connection.close
          logger.debug "@@@@@@@@@@ CURRENT_USER ENSURE ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          # ActiveRecord::Base.connection_pool.release_connection
          # ActiveRecord::Base.connection_pool.checkin(main_thread_conn)
          # ActiveRecord::Base.connection_pool.disconnect!
          # puts "@@@@@@@@@@   Active connections CURRENT_USER ==> #{ActiveRecord::Base.connection_pool.connections.size} @@@@@@@@@@@@@@@@"
          # puts "@@@@@@@@@@   Waiting connections CURRENT_USER ==> #{ActiveRecord::Base.connection_pool.num_waiting_in_queue} @@@@@@@@@@@@@@@@"
          # ActiveRecord::Base.connection_pool.clear_reloadable_connections!
          # ActiveRecord::Base.clear_active_connections!
          # ActiveRecord::Base.connection.close
        end
      elsif(user_id = cookies.signed[:user_id])
        begin
          user = User.find_by(id: user_id)
        rescue Exception => e
          logger.debug "@@@@@@@@@@ Thread is sleeping RESCUE #{e} @@@@@@@@@@@@@@@@"
        ensure
          logger.debug "@@@@@@@@@@ Thread in CURRENT_USER ENSURE @@@@@@@@@@@@@@@@"
          # User.connection_pool.release_connection
          User.connection.close
          logger.debug "@@@@@@@@@@ CURRENT_USER ENSURE ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
        end
        if user && user.authenticated?(cookies[:remember_token])
          log_in user
          @current_user = user
        end
      end
      return @current_user
    end

    def forget(user)
      user.forget
      cookies.delete(:user_id)
      cookies.delete(:remember_token)
    end

    def logged_in?
      !current_user.nil?
    end

    def log_out
      forget(current_user)
      logout_service_providers(current_user.id)
      session.delete(:user_id)
      @current_user = nil
    end

    def logout_service_providers(user_id)
      ServiceTicket.where(user_id: user_id).each do |service_ticket|
        make_logout_request(service_ticket.url, service_ticket.token)
        # make_logout_request(service_ticket.token, service_ticket.url + "/logout")
        service_ticket.destroy
      end
    end

    def make_logout_request(url_string, token)
      require 'net/http'
      url = URI.parse(url_string)
      base_url_string = url_string.split(url.request_uri).first
      logout_url = URI.parse(base_url_string + "/authentications/logout")
      params = { :token => token }
      logout_url.query = URI.encode_www_form(params)
      res = Net::HTTP.get_response(logout_url)
      # req = Net::HTTP::Get.new(logout_url.to_s)
      # res = Net::HTTP.start(logout_url.host, logout_url.port) {|http|
      #   http.request(req)
      # }
      puts res.body
    end

    def encode_jwt_token(data_hash)
      # exp = Time.now.to_i + ENV.fetch("EXPIRE_AFTER_SECONDS") { 1.hour }.to_i
      # payload = { :data => data_hash, :exp => exp }
      payload = { :data => data_hash }
      hmac_secret = 'my$ecretK3y'
      JWT.encode payload, hmac_secret, 'HS256'
    end

    def decode_jwt_token(token)
      hmac_secret = Rails.configuration.sso_settings["identity_provider_secret_key"]
      begin
        decoded_token = JWT.decode token, hmac_secret, true, { :algorithm => 'HS256' }
        payload = decoded_token.select{|decoded_part| decoded_part.key?("data") }.last
        return payload
      rescue JWT::ExpiredSignature
        # Handle expired token, e.g. logout user or deny access
        puts "Token expired thus redirecting to root_url"
        redirect_to root_url and return
      end
    end

    def generate_url(url, params = {})
      uri = URI(url)
      uri.query = params.to_query
      uri.to_s
    end

    def authenticate_or_redirect_to_login(service_url = nil)
      # service_url ||= params[:service_url]
      if logged_in?
        if params[:token].present? && (service_url = get_service_url(params[:token])).present?
          redirect_to_service_provider(service_url, current_user)
          return
        end
      else
        after_logout_path
        return
      end
    end

    def get_service_url(jwt_token)
      payload = decode_jwt_token(params[:token])
      payload.present? ? payload["data"]["service_url"] : nil
    end

    def redirect_to_service_provider(service_url, user)
      if (service_ticket = ServiceTicket.where(user_id: user.id).last)
        token = service_ticket.token
      else
        token = encode_jwt_token({email: user.email})
      end
      ServiceTicket.create(user_id: user.id, url: service_url, token: token)
      redirect_to generate_url(service_url, {token: token}), status: 303
    end
  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
end

class ApplicationController < ActionController::Base
  include AuthenticationsHelper
  before_action :authenticate_or_redirect_to_login, except: [:login]
end

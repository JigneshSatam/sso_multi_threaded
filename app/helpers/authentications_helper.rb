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
      exp = Time.now.to_i + ENV.fetch("EXPIRE_AFTER_SECONDS") { 1.hour }.to_i
      payload = { :data => data_hash, :exp => exp }
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

    def authenticate_or_redirect_to_login
      if logged_in?
        if (service_url = get_service_url).present?
          redirect_to_service_provider(service_url, current_user) and return
        else
          return nil
        end
      else
        # redirect_to after_logout_path and return
        after_logout_path
        return
      end
    end

    def get_service_token
      return (params[:service_token] || session[:service_token])
    end

    def get_service_url
      service_token = get_service_token
      return nil if service_token.blank?
      payload = decode_jwt_token(service_token)
      payload.present? ? payload["data"]["service_url"] : nil
    end

    def redirect_to_service_provider(service_url, user)
      token = encode_jwt_token({email: user.email})
      ServiceTicket.create(user_id: user.id, url: service_url, token: token)
      clear_session_service_token
      redirect_to(generate_url(service_url, {token: token}), status: 303) and return
    end

    def set_session_service_token
      path_key = nil
      if params[:service_token].present?
        token = params[:service_token]
      elsif request.referer.present?
      # elsif request.referer.present? && (url = URI.parse(request.referer))
        # path_key = (url.to_s.split(url.request_uri).last)
        # path_key.chomp!("/")
        path_key = request.referer
        if session[path_key].present?
          token = session[path_key]
          session[path_key] = nil # Remove old session key
        end
      end
      if token.present?
        if logged_in?
          session[:service_token] = token
          response.location = get_service_url
          response.status = 303
          session[path_key] = nil if path_key.present?
          session[:service_token] = nil
          return
        end
        if response.location.blank?
          # path_key = request.query_string.present? ? request.original_url.split("?" + request.query_string).last : request.original_url
          # path_key.chomp!("/")
          path_key = request.original_url
        end
        session[path_key] = token # Set new session key
      end
    end

    def clear_session_service_token
      session[:service_token] = nil
    end
  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end

class ApplicationController < ActionController::Base
  include AuthenticationsHelper
  after_action :set_session_service_token
  before_action :authenticate_or_redirect_to_login, except: [:login]
end

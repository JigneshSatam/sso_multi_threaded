module IdentityProvider
  module Login
    module ClassMethods

    end

    module Shared
      def model
        @model ||= Rails.configuration.sso_settings["model"].camelcase.constantize
      end
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
            @current_user ||= model.find_by(id: user_id)
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
            model.connection.close
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
            user = model.find_by(id: user_id)
          rescue Exception => e
            logger.debug "@@@@@@@@@@ Thread is sleeping RESCUE #{e} @@@@@@@@@@@@@@@@"
          ensure
            logger.debug "@@@@@@@@@@ Thread in CURRENT_USER ENSURE @@@@@@@@@@@@@@@@"
            # User.connection_pool.release_connection
            model.connection.close
            logger.debug "@@@@@@@@@@ CURRENT_USER ENSURE ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          end
          if user && user.authenticated?(cookies[:remember_token])
            log_in user
            @current_user = user
          end
        elsif (jwt_token = params[:token]).present?
          payload = decode_jwt_token(jwt_token)
          @current_user ||= model.find_by(email: payload["data"]["email"])
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
            service_url = get_service_url
            redirect_to_service_provider(service_url, current_user) if service_url.present?
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
        token = encode_jwt_token({email: user.email, session: session.id})
        ServiceTicket.create(user_id: user.id, url: service_url, token: token)
        clear_session_service_token
        if response.location.present?
          response.location = generate_url(service_url, {token: token})
          response.status = 303
          return
        else
          redirect_to(generate_url(service_url, {token: token}), status: 303) and return
        end
      end
    end

    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
      receiver.send :include, Shared
    end
  end
end

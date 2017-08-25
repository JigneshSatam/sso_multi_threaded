module IdentityProvider
  module Login
    module ClassMethods

    end
    module InstanceMethods
      def log_in(model_instance)
        session[:model_instance_id] = model_instance.id
        set_session_expire_at
      end

      def set_session_expire_at
        if session_timeout.present?
          session[:expire_at] = (Time.now + session_timeout)
        end
      end

      def session_expired?
        return session[:expire_at].present? && Time.now > session[:expire_at]
      end

      # Remembers a user in a persistent session.
      def remember(model_instance)
        encoded_model_instance_id = Token.encode_jwt_token({model_instance_id: model_instance.id})
        cookies.permanent.signed[:remember_token] = encoded_model_instance_id
      end

      def current_user
        if session_expired?
          previous_model_instance_id = session[:model_instance_id]
          session.delete(:model_instance_id)
          @current_user = nil
        end
        return @current_user if !@current_user.nil?
        if (model_instance_id = session[:model_instance_id])
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
            @current_user ||= model.find_by(id: model_instance_id)
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
        elsif(remember_token = cookies.signed[:remember_token])
          begin
            payload = Token.decode_jwt_token(remember_token)
            model_instance_id = payload["data"]["model_instance_id"]
            @current_user ||= model.find_by(id: model_instance_id)
          rescue Exception => e
            logger.debug "@@@@@@@@@@ Thread is sleeping RESCUE #{e} @@@@@@@@@@@@@@@@"
          ensure
            logger.debug "@@@@@@@@@@ Thread in CURRENT_USER ENSURE @@@@@@@@@@@@@@@@"
            # User.connection_pool.release_connection
            model.connection.close
            logger.debug "@@@@@@@@@@ CURRENT_USER ENSURE ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          end
          # if user && user.authenticated?(cookies[:remember_token])
          #   log_in user
          #   @current_user = user
          # end
        elsif (jwt_token = params[:token]).present?
          payload = Token.decode_jwt_token(jwt_token)
          @current_user ||= model.find_by(uniq_identifier.to_sym => payload["data"]["uniq_identifier"])
        end
        if @current_user.present?
          set_session_expire_at
        else
          logout_service_providers(previous_model_instance_id) if previous_model_instance_id
          clear_session(session.id)
        end
        return @current_user
      end

      def logged_in?
        !current_user.nil?
      end

      def set_session_service_token
        if has_service_token?
          if response.location.blank?
            path_key = request.original_url
          else
            path_key = response.location
          end
          set_service_token_in_token_keeper(path_key, get_service_token) # Set new session key
        end
      end

      def get_service_token
        return @service_token if @service_token.present?
        # return (params[:service_token] || session[:service_token])
        if params[:service_token].present?
          @service_token = params[:service_token]
        elsif (referer = request.referer).present? && session[:token_keeper].present? && session[:token_keeper][referer].present?
        # elsif request.referer.present? && (url = URI.parse(request.referer))
          # path_key = (url.to_s.split(url.request_uri).last)
          # path_key.chomp!("/")
          # path_key = request.referer
            @service_token = session[:token_keeper][referer]
          # if
            # session[path_key] = nil # Remove old session key
          # end
        end
        return @service_token
      end

      def has_service_token?
        return get_service_token.present?
      end

      def set_service_token_in_token_keeper(key, token)
        session[:token_keeper] = {key => token}
      end

      def generate_url(url, params = {})
        uri = URI(url)
        uri.query = params.to_query
        uri.to_s
      end

      def get_service_url
        service_token = get_service_token
        return nil if service_token.blank?
        payload = Token.decode_jwt_token(service_token)
        payload.present? ? payload["data"]["service_url"] : nil
      end

      def redirect_to_service_provider_and_set_service_ticket(service_url, model_instance)
        token = Token.encode_jwt_token({uniq_identifier: model_instance.send(uniq_identifier.to_sym), session: session.id}, ENV.fetch("EXPIRE_AFTER_SECONDS") { 1.hour })
        ServiceTicket.create(model_instance_id: model_instance.id, url: service_url, token: session.id)
        clear_session_service_token
        safe_redirection(generate_url(service_url, {token: token}), 303)
      end

      def clear_session_service_token
        session[:token_keeper] = nil
      end

      def safe_redirection(url, status = 302)
        if response.location.present?
          response.location = url
          response.status = status
          return
        else
          redirect_to(url, status: status) and return
        end
      end

      def redirect_to_service_provider
        ErrorPrinter.print_error("Redirecting to service provider.", "This request came from service provider.")
        return redirect_to_service_provider_and_set_service_ticket(get_service_url, current_user) if logged_in?
      end

      def logged_in_user_has_service_token
        return logged_in? && has_service_token?
      end
    end

    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
      receiver.send :include, Authentication
    end
  end
end

module IdentityProvider
  module Login
    module ClassMethods

    end

    module Shared
      def print_error(msg, flash_msg = nil)
        msg = "\e[31m#{msg}\e[0m"
        msg = "\e[1m#{msg}\e[22m"
        flash_msg ||= "Follow the below instructions"
        flash_msg = "\e[36m#{flash_msg}\e[0m"
        flash_msg = "\e[1m#{flash_msg}\e[22m"
        flash_msg = "\e[5m#{flash_msg}\e[25m"
        print "\n"
        logger.info(flash_msg)
        logger.info(msg)
        print "\n"
      end

      def model
        begin
          @model ||= Rails.configuration.sso_settings["model"].camelcase.constantize
        rescue Exception => e
          print_error("Insert vaid model name in sso_settings.yml file as value for the key 'model' eg: `model: 'user'` if User is the model")
          raise e
        end
      end

      def uniq_identifier
        return @uniq_identifier if @uniq_identifier
        begin
          raise "model_uniq_identifier missing in sso_settings.yml" if Rails.configuration.sso_settings["model_uniq_identifier"].blank?
        rescue Exception => e
          print_error("Insert key value pair in sso_settings.yml file eg: `model_uniq_identifier: 'email'` if email is a column")
          raise e
        else
          return (@uniq_identifier = Rails.configuration.sso_settings["model_uniq_identifier"])
        end
      end

      def sso_secret_key
        return @sso_secret_key if @sso_secret_key
        begin
          raise "identity_provider_secret_key missing in sso_settings.yml" if Rails.configuration.sso_settings["identity_provider_secret_key"].blank?
        rescue Exception => e
          print_error("Insert key value pair in sso_settings.yml file eg: identity_provider_secret_key: 'my$ecretK3y'")
          raise e
        else
          return (@sso_secret_key = Rails.configuration.sso_settings["identity_provider_secret_key"])
        end
      end

      def session_timeout
        return @session_timeout if @session_timeout
        if (@session_timeout = Rails.configuration.sso_settings["sso_session_timeout"]).present?
          return (@session_timeout = @session_timeout.to_i.minutes)
        else
          session[:expire_at] = nil if session[:expire_at].present?
          print_error("Insert key value pair in sso_settings.yml file eg: `sso_session_timeout: '10'` 10 are in minutes", "You have not set session_timeout")
        end
      end
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
        encoded_model_instance_id = encode_jwt_token({model_instance_id: model_instance.id})
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
            payload = decode_jwt_token(remember_token)
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
          payload = decode_jwt_token(jwt_token)
          @current_user ||= model.find_by(uniq_identifier.to_sym => payload["data"]["email"])
        end
        if @current_user.present?
          set_session_expire_at
        else
          logout_service_providers(previous_model_instance_id) if previous_model_instance_id
        end
        return @current_user
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

      def redirect_to_service_provider(service_url, model_instance)
        token = encode_jwt_token({email: model_instance.send(uniq_identifier.to_sym), session: session.id}, ENV.fetch("EXPIRE_AFTER_SECONDS") { 1.hour })
        ServiceTicket.create(model_instance_id: model_instance.id, url: service_url, token: token)
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

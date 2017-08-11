module IdentityProvider
  module Logout
    module ClassMethods

    end

    module InstanceMethods
      def log_out(jwt_token = nil)
        if jwt_token.present?
          log_out_from_service_provider(jwt_token)
        else
          log_out_from_identity_provider
        end
      end

      def log_out_from_identity_provider
        forget(current_user)
        logout_service_providers(current_user.id)
        session.delete(:model_instance_id)
        @current_user = nil
      end

      def log_out_from_service_provider(jwt_token)
        payload = decode_jwt_token(jwt_token)
        session_id = payload["data"]["session"]
        logger.debug "authentication_helper %% clear_session ====> started <===="
        store = ActionDispatch::Session::RedisStore.new(Rails.application, Rails.application.config.session_options)
        number_of_keys_removed = store.with{|redis| redis.del(session_id)}
        logger.debug "logging_out number_of_keys_removed ====> #{number_of_keys_removed} <===="
        # ServiceTicket.where(token: jwt_token).joins("INNER JOIN service_tickets as st ON  st.user_id=service_tickets.user_id").where("token NOT ILIKE ?", jwt_token)
        service_tickets_url_token_arrays = ServiceTicket.joins("INNER JOIN service_tickets as st ON st.model_instance_id=service_tickets.model_instance_id").where("st.token ILIKE ?", jwt_token).destroy_all.pluck(:url, :token)
        make_threaded_logout_request(service_tickets_url_token_arrays)
        # ServiceTicket.joins("INNER JOIN service_tickets ON users.id = service_tickets.user_id").where(email: email)
      end

      def logout_service_providers(model_instance_id)
        service_tickets_url_token_arrays = ServiceTicket.where(model_instance_id: model_instance_id).destroy_all.pluck(:url, :token)
        make_threaded_logout_request(service_tickets_url_token_arrays)
      end

      def make_threaded_logout_request(url_token_arrays)
        threads = []
        url_token_arrays.each do |url_token_array_tuple|
          threads << Thread.new { make_logout_request(url_token_array_tuple[0], url_token_array_tuple[1]) }
        end
        # threads.each { |thread| thread.join }
        threads.each { |thread| thread.join(0.5) }
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

      def clear_session_service_token
        session[:service_token] = nil
      end
    end

    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
  end
end

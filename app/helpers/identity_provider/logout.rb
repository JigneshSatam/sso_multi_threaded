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
        session.delete(:user_id)
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
        ServiceTicket.joins("INNER JOIN service_tickets as st ON st.user_id=service_tickets.user_id").where("st.token ILIKE ?", jwt_token).each do |service_ticket|
          if service_ticket.token != jwt_token
            make_logout_request(service_ticket.url, service_ticket.token)
            # make_logout_request(service_ticket.token, service_ticket.url + "/logout")
          end
          service_ticket.destroy
        end
        # ServiceTicket.joins("INNER JOIN service_tickets ON users.id = service_tickets.user_id").where(email: email)
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

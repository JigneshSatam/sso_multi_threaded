module AuthenticationsHelper
  module ClassMethods

  end

  module InstanceMethods
    def generate_url(url, params = {})
      uri = URI(url)
      uri.query = params.to_query
      uri.to_s
    end

    def authenticate_or_redirect_to_login
      # return nil if (params[:action] == "login" && params[:controller] == "authentications")
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
  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
    receiver.send :include, IdentityProvider::Login
    receiver.send :include, IdentityProvider::Logout
  end

end

class ApplicationController < ActionController::Base
  include AuthenticationsHelper
  after_action :set_session_service_token
  before_action :authenticate_or_redirect_to_login
end

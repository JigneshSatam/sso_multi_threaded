module AuthenticationsHelper
  module ClassMethods

  end

  module InstanceMethods
    def check_authentication
      unless logged_in?
        ErrorPrinter.print_error("Sorry, you need to login before continuing.", "Login required.")
        flash[:alert] = "Sorry, you need to login before continuing."
        return redirect_to unauthenticated_path, status: 302
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
  before_action :check_authentication
  skip_before_action :check_authentication, only: [:unauthenticated]
  after_action :redirect_to_service_provider, if: :logged_in_user_has_service_token
  after_action :set_session_service_token, if: :has_service_token?
end

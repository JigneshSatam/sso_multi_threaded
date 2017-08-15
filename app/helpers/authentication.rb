module Authentication
  def self.encode_jwt_token(data_hash, expire_after = nil)
    payload = { :data => data_hash }
    if expire_after.present?
      exp = Time.now.to_i + expire_after.to_i.minutes.to_i
      payload.merge!({exp: exp})
      # exp = Time.now.to_i + ENV.fetch("EXPIRE_AFTER_SECONDS") { 1.hour }.to_i
      # payload = { :data => data_hash, :exp => exp }
    end
    hmac_secret = sso_secret_key
    JWT.encode payload, hmac_secret, 'HS256'
  end

  def self.decode_jwt_token(token)
    hmac_secret = sso_secret_key
    begin
      decoded_token = JWT.decode token, hmac_secret, true, { :algorithm => 'HS256' }
      payload = decoded_token.select{|decoded_part| decoded_part.key?("data") }.last
      return payload
    rescue JWT::ExpiredSignature
      # Handle expired token, e.g. logout user or deny access
      puts "Token expired thus redirecting to root_url"
      if response.location.blank?
        redirect_to root_url and return
      else
        response.location = root_url
        response.status = 301
        return
      end
    end
  end

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

  public
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
      if Rails.configuration.sso_settings["sso_session_timeout"].to_i > 0
        return (@session_timeout = Rails.configuration.sso_settings["sso_session_timeout"].to_i.minutes)
      else
        session[:expire_at] = nil if session[:expire_at].present?
        print_error("Insert key value pair in sso_settings.yml file eg: `sso_session_timeout: '10'` 10 are in minutes", "You have not set session_timeout")
      end
    end
  module_function :sso_secret_key

  module ClassMethods
  end

  def self.included(receiver)
    receiver.extend ClassMethods
  end
end

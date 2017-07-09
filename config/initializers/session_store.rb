# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store, key: '_sso_session', expire_after: ENV.fetch("EXPIRE_AFTER_SECONDS") { 1.hour }.to_i

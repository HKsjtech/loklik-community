# frozen_string_literal: true

module ::HelloModule
  class AdminCommonController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    include MyHelper
    rescue_from StandardError, with: :handle_error
    before_action :set_current_user

    def handle_error(exception)
      case exception
      when RateLimiter::LimitExceeded
        LoggerHelper.warn(exception.full_message)
        LoggerHelper.warn(exception.description)
        render_response(success: false, code: 400, msg: exception.description)
      when Discourse::InvalidAccess
        LoggerHelper.warn(exception.full_message)
        LoggerHelper.warn(exception.message)
        render_response(code: 400, success: false, msg: I18n.t("invalid_access"))
      else
        LoggerHelper.error(exception.full_message)
        render_response(success: false, code: 400, msg: I18n.t('loklik.operation_failed'))
      end
    end

    def set_current_user
      @current_user = current_user
    end
  end
end

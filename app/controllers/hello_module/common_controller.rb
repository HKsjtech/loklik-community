# frozen_string_literal: true

module ::HelloModule
  class CommonController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    include MyHelper
    before_action :set_language
    rescue_from StandardError, with: :handle_error

    def set_language
      # 设置语言
      I18n.locale = SiteSetting.default_locale
      accept_language_orig = request.get_header("HTTP_ACCEPT_LANGUAGE")

      # 判断当前语言是否支持
      if accept_language_orig.present?
        # accept_language eg：zh-CN to zh_CN
        accept_language = accept_language_orig.tr('-', '_')
        if I18n.available_locales.include?(accept_language.to_sym)
          I18n.locale = accept_language
        else
          LoggerHelper.error("unsupported accept_language: #{accept_language_orig}")
        end
      end
    end

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
  end
end

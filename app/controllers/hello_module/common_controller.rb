# frozen_string_literal: true

module ::HelloModule
  class CommonController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    include MyHelper
    before_action :set_language

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

  end
end

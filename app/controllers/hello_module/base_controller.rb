# frozen_string_literal: true

require_relative '../base_module/response'

module ::HelloModule
  class BaseController < ::ApplicationController
    include BaseModule
    requires_plugin PLUGIN_NAME
    skip_before_action :verify_authenticity_token # 跳过认证

    def banner_list
      banner_plugin_name = "Big Carousel"
      theme = Theme.find_by(name: banner_plugin_name)

      if theme.nil?
        render json: { msg: 'theme not found. theme: ' + banner_plugin_name}
        return
      end

      theme_setting = ThemeSetting.find_by(theme_id: theme.id)
      if theme_setting.nil?
        render json: { msg: 'theme setting not found. theme: ' + banner_plugin_name}
        return
      end

      render_response(data: JSON.parse(theme_setting.value))
    end

    def is_sync
      # todo: need to implement
      render_response(data: { is_sync: true })
    end

    def search
      # todo: need to implement
      render_response(data: { search: 'search' })
    end

    def upload
      # todo: need to implement
      render_response(data: { upload: 'upload' })
    end

    def discourse_host
      # todo: need to implement
      render_response(data: { discourse_host: "https://www.loklik.cc" })
    end


  end
end


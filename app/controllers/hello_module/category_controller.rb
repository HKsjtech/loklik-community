# frozen_string_literal: true
require_relative '../base_module/response'

module ::HelloModule
  class CategoryController < ::ApplicationController
    include BaseModule
    requires_plugin PLUGIN_NAME
    skip_before_action :verify_authenticity_token # 跳过认证

    def region_list
      # todo: need to implement
      render_response(data: { region_list: 'region_list' })
    end

    def all
      # todo: need to implement
      render_response(data: 'all')
    end

    def list
      # todo: need to implement
      render_response(data: 'list')
    end

    def show
      # todo: need to implement
      render_response(data: 'show')
    end

  end
end

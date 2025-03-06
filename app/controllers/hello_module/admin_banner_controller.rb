# frozen_string_literal: true

module ::HelloModule
  class AdminBannerController < ::ApplicationController
    include MyHelper
    requires_plugin PLUGIN_NAME
    before_action :set_current_user

    def list
      banners = AppBanner.all.order(sort: :desc)
      res = banners.to_json(only: [:id, :name, :image_url, :link_url, :sort])
      render_response(data: res)
    end

    def create
      banner = AppBanner.new(
        name: params[:name],
        image_url: params[:image_url],
        link_url: params[:link_url],
        sort: params[:sort],
      )
      if banner.save
        render_response(success: true, msg: I18n.t('loklik.operation_success'))
      else
        render_response(success: false, msg: I18n.t('loklik.operation_failed'))
      end
    end

    def update
      banner = AppBanner.find(params[:id])
      banner.name = params[:name]
      banner.image_url = params[:image_url]
      banner.link_url = params[:link_url]
      banner.sort = params[:sort]
      if banner.save
        render_response(success: true, msg: I18n.t('loklik.operation_success'))
      else
        render_response(success: false, msg: I18n.t('loklik.operation_failed'))
      end
    end

    private
    def set_current_user
      @current_user = current_user
    end

  end
end

# frozen_string_literal: true

module ::HelloModule
  class AdminBannerController < ::ApplicationController
    include MyHelper
    requires_plugin PLUGIN_NAME
    before_action :set_current_user

    def list
      name = params[:name]
      status = params[:status]

      banners = AppBanner
      banners = banners.where('name LIKE ?', "%#{name}%") if name.present?
      banners = banners.where(status: status) if status.present?
      banners = banners.order(sort: :desc)

      res = banners.to_json(only: [:id, :name, :app_image_url, :paid_app_image_url, :update_user_name, :link_url, :sort, :status, :created_at, :updated_at])
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
        render_response
      else
        render_response
      end
    end

    def update
      banner = AppBanner.find(params[:id])
      banner.name = params[:name]
      banner.image_url = params[:image_url]
      banner.link_url = params[:link_url]
      banner.sort = params[:sort]
      if banner.save
        render_response
      else
        render_response
      end
    end

    private
    def set_current_user
      @current_user = current_user
    end

  end
end

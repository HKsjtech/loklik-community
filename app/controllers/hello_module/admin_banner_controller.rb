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
      banners = banners.order(sort: :desc).order(status: :desc)

      res = banners.to_json(only: [:id, :name, :app_image_url, :paid_app_image_url, :update_user_name, :link_url, :sort, :status, :created_at, :updated_at])
      render_response(data: res)
    end

    def create
      banner = AppBanner.new(
        name: params[:name],
        app_image_url: params[:app_image_url],
        pad_image_url: params[:pad_image_url],
        link_url: params[:link_url],
        sort: params[:sort],
        status: 1, # 保存直接上架
        update_user_id: @current_user.id,
        update_user_name: @current_user.name,
        operate_time: Time.now,
        )

      if banner.save
        render_response
      else
        render_response(msg: banner.errors.full_messages, code: 400)
      end
    end

    def update
      id = params.require(:id).to_i
      banner = AppBanner.find_by(id)
      if banner.nil?
        return render_response(msg: 'Banner not found', code: 404)
      end

      if params[:status] == '0' || params[:status] == '1'
        banner.status = params[:status]
        banner.update_user_id = @current_user.id
        banner.update_user_name = @current_user.name
        banner.operate_time = Time.now
      end

      if params[:name]
        banner.name = params[:name]
      end

      if params[:app_image_url]
        banner.app_image_url = params[:app_image_url]
      end

      if params[:pad_image_url]
        banner.pad_image_url = params[:pad_image_url]
      end

      if params[:link_url]
        banner.link_url = params[:link_url]
      end

      if params[:sort]
        banner.sort = params[:sort]
      end

      if banner.save
        render_response
      else
        render_response(msg: banner.errors.full_messages, code: 400)
      end

    end


    private
    def set_current_user
      @current_user = current_user
    end

  end
end

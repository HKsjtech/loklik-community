# frozen_string_literal: true
require 'aws-sdk-s3'

module ::HelloModule
  class BaseController < ::ApplicationController
    include MyHelper
    include MyS3Helper
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

      theme_settings = JSON.parse(theme_setting.value)
      res = []
      theme_settings.each do |item|
        res.push(serialize_theme_setting(item))
      end

      render_response(data: res)
    end

    def search
      # todo: need to implement
      render_response(data: { search: 'search' })
    end

    def upload
      user_id = request.env['current_user_id']
      me = User.find_by_id(user_id) # 验证用户是否存在
      type = params[:type] # 0-图片 1-视频 2-封面图
      cover_img = params[:coverImg] # 封面图 当上传视频时，必传
      thumbnail_width = params[:thumbnailWidth] # 缩略图宽度 当上传视频时，必传
      thumbnail_height = params[:thumbnailHeight] # 缩略图高度 当上传视频时，必传
      # 处理上传的文件
      file = params[:file]

      case type
      when "0", "2"
        upload_image(file, me)
        nil
      when "1"
        # 处理上传的文件
        enable_s3_uploads = SiteSetting.enable_s3_uploads
        unless enable_s3_uploads
          render_response(data: { success: false, message: 'S3 上传未开启' }, code: 400)
          return
        end
        unless cover_img && thumbnail_width && thumbnail_height
          render_response(data: { success: false, message: '缺少必要参数' }, code: 400)
          return
        end
        public_url = upload_file(file)
        app_video_upload = AppVideoUpload.new(
          url: public_url,
          original_name: file.original_filename,
          file_size: file.size,
          thumbnail_width: thumbnail_width,
          thumbnail_height: thumbnail_height,
          extension: File.extname(file.original_filename),
          cover_img: cover_img,
          )
        unless app_video_upload.save
          render_response(data: nil, msg: '上传失败', code: 500)
          return
        end
       render_response(data: {
          "id": app_video_upload.id,
          "url": app_video_upload.url,
          "originalName": app_video_upload.original_name,
          "fileSize": app_video_upload.file_size,
          "thumbnailWidth": app_video_upload.thumbnail_width,
          "thumbnailHeight":app_video_upload.thumbnail_height,
          "extension": app_video_upload.extension,
          "shortUrl": "",
        })
        nil
      else
        render_response(data: nil, code: 400, success: false, msg: '上传类型错误')
      end
    rescue => e
      LoggerHelper.error("upload error: #{e.message}")
      render_response(data: nil, msg: '上传失败', code: 500)
    end

    def discourse_host
      render_response(data: { discourseHost: Discourse.base_url })
    end

    private

    def serialize_theme_setting(theme_setting)
      {
        "link": theme_setting["link"],
        "headline": theme_setting["headline"],
        "text": theme_setting["text"],
        "textBg": theme_setting["text_bg"],
        "buttonText": theme_setting["button_text"],
        "imageUrl": theme_setting["image_url"],
        "slideBgColor": theme_setting["slide_bg_color"],
        "slideType": theme_setting["slide_type"],
      }
    end

    def upload_image(file, me)
      url = params[:url]
      pasted = params[:pasted] == "true"
      for_private_message = params[:for_private_message] == "true"
      for_site_setting = params[:for_site_setting] == "true"
      is_api = is_api?
      retain_hours = params[:retain_hours].to_i
      type = "composer"
      begin
        info = UploadsController.create_upload(
          current_user: me,
          file: file,
          url: url,
          type: type,
          for_private_message: for_private_message,
          for_site_setting: for_site_setting,
          pasted: pasted,
          is_api: is_api,
          retain_hours: retain_hours,
        )
      rescue => e
        result = failed_json.merge(message: e.message.split("\n").first)
      else
        result = UploadsController.serialize_upload(info)
      end

      render_response(data: {
        "id": result["id"],
        "url": result["url"],
        "originalName": result["original_name"],
        "fileSize": result["filesize"],
        "thumbnailWidth": result["thumbnail_width"],
        "thumbnailHeight": result["thumbnail_height"],
        "extension": result["extension"],
        "shortUrl": result["short_url"],
      })
    end

  end
end


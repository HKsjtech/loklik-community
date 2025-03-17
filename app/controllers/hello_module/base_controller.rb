# frozen_string_literal: true
require 'aws-sdk-s3'

module ::HelloModule
  class BaseController < CommonController
    include MyHelper
    include MyS3Helper
    include PostHelper
    include AuthHelper
    requires_plugin PLUGIN_NAME
    skip_before_action :verify_authenticity_token # 跳过认证

    def banner_list
      banner_plugin_name = "Big Carousel"
      theme = Theme.find_by(name: banner_plugin_name)

      if theme.nil?
        render_response(data: nil, code: 404, success: false, msg: 'theme not install. theme: ' + banner_plugin_name)
        return
      end

      theme_setting = ThemeSetting.find_by(theme_id: theme.id, data_type: 2)
      if theme_setting.nil?
        render_response(data: nil, code: 404, success: false, msg: 'theme not found.')
        return
      end
      theme_settings = JSON.parse(theme_setting.value)

      res = []
      theme_settings.each do |item|
        res.push(serialize_theme_setting(item))
      end

      render_response(data: res)
    end

    def app_banner
      res = AppBanner.where(status: 1).order(sort: :desc).all
      res = res.map do |banner|
        {
          id: banner.id,
          name: banner.name,
          appImageUrl: banner.app_image_url,
          padImageUrl: banner.pad_image_url,
          linkUrl: banner.link_url,
          sort: banner.sort,
          status: banner.status
        }
      end

      render_response(data: res)
    end

    def search
      user_id = get_current_user_id
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i
      search_key = params.require(:q)

      query = Topic
                .select('topics.id')
                .joins('LEFT JOIN posts ON posts.topic_id = topics.id')
                .where("topics.title LIKE ? OR posts.raw LIKE ?", "%#{search_key}%", "%#{search_key}%")
                .where("posts.post_number = ?", 1)
                .where(deleted_by_id: nil, archetype: 'regular',visible: true, closed: false, category_id: all_category_ids)
                .order(id: :desc)
      topics = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      res = PostService.cal_topics_by_topic_ids(topics.map(&:id), user_id)

      # 如果搜索的为链接里面的内容，会被额外搜索到，所以需要过滤掉
      res = res.filter { |item| item["context"].include?(search_key) || item["title"].include?(search_key) }

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def upload
      user_id = get_current_user_id

      me = User.find_by_id(user_id) # 验证用户是否存在
      type = params[:type] # 0-图片 1-视频 2-封面图
      cover_img = params[:coverImg] # 封面图 当上传视频时，必传
      thumbnail_width = params[:thumbnailWidth] # 缩略图宽度 当上传视频时，必传
      thumbnail_height = params[:thumbnailHeight] # 缩略图高度 当上传视频时，必传
      # 处理上传的文件
      file = params[:file]

      case type #0-图片 1-视频 2-封面图
      when "0"
        if file.size > SiteSetting.max_upload_image_size * 1024 * 1024
          return render_response(data: nil, code: 400, success: false, msg: I18n.t("loklik.file_too_large", size: SiteSetting.max_upload_image_size))
        end
        unless UploadService.check_upload_image_limit(user_id)
          return render_response(data: nil, success: false, msg: I18n.t("loklik.upload_image_limit", limit: SiteSetting.max_upload_image_user_per_day), code: 400)
        end

        upload_image(file, me)

        UploadService.incr_upload_images_count(user_id)
        nil
      when "2"
        enable_s3_uploads = SiteSetting.enable_s3_uploads
        unless enable_s3_uploads
          render_response(data: nil, code: 400, msg: I18n.t("loklik.upload_video_s3_disabled"), success: false)
          return
        end
        if file.size > SiteSetting.max_upload_image_size * 1024 * 1024
          return render_response(data: nil, code: 400, success: false, msg: I18n.t("loklik.file_too_large", size: SiteSetting.max_upload_image_size))
        end
        unless UploadService.check_upload_image_limit(user_id)
          return render_response(data: nil, success: false, msg: I18n.t("loklik.upload_image_limit", limit: SiteSetting.max_upload_image_user_per_day), code: 400)
        end

        url = upload_file(file)

        UploadService.incr_upload_images_count(user_id)

        render_response(data: {
          url: url,
        })
      when "1"
        # 处理上传的文件
        enable_s3_uploads = SiteSetting.enable_s3_uploads
        unless enable_s3_uploads
          render_response(data: nil, code: 400, msg: I18n.t("loklik.upload_video_s3_disabled"), success: false)
          return
        end
        unless cover_img && thumbnail_width && thumbnail_height
          render_response(data: { success: false, message: I18n.t("loklik.params_error", params: "coverImg, thumbnailWidth, thumbnailHeight") }, code: 400)
          return
        end
        unless UploadService.check_upload_video_limit(user_id)
          return render_response(data: nil, success: false, msg: I18n.t("loklik.upload_video_limit", limit: SiteSetting.max_upload_videos_user_per_day), code: 400)
        end

        if file.size > SiteSetting.max_upload_video_size * 1024 * 1024
          return render_response(data: nil, code: 400, success: false, msg: I18n.t("loklik.file_too_large", size: SiteSetting.max_upload_video_size))
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
          render_response(data: nil, msg: I18n.t("loklik.operation_failed"), code: 500)
          return
        end

        UploadService.incr_upload_videos_count(user_id)
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
        render_response(data: nil, code: 400, success: false, msg: I18n.t("loklik.params_error", params: "type"))
      end
    rescue => e
      LoggerHelper.error("upload error: #{e.message}")
      render_response(data: nil, msg: I18n.t("loklik.operation_failed"), code: 500)
    end

    def discourse_host
      render_response(data: { discourseHost: Discourse.base_url })
    end

    def settings
      settings = {
        "max_upload_videos_user_per_day": SiteSetting.max_upload_videos_user_per_day,
        "max_upload_video_size":  SiteSetting.max_upload_video_size,
        "max_upload_image_size":  SiteSetting.max_upload_image_size,
        "max_upload_image_user_per_day": SiteSetting.max_upload_image_user_per_day,
        "remaining_upload_images": UploadService.get_remaining_upload_images(get_current_user_id),
        "remaining_upload_videos": UploadService.get_remaining_upload_videos(get_current_user_id)
      }

      render_response(data: settings)
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
        "url": format_url(result["url"]),
        "originalName": result["original_filename"],
        "fileSize": result["filesize"],
        "thumbnailWidth": result["thumbnail_width"],
        "thumbnailHeight": result["thumbnail_height"],
        "extension": result["extension"],
        "shortUrl": result["short_url"],
      })
    end

  end
end


module ::HelloModule
  class UploadService
    extend PostHelper
    extend DiscourseHelper

    def self.upload_image(file, upload_user, params)
      url = params[:url]
      pasted = params[:pasted] == "true"
      for_private_message = params[:for_private_message] == "true"
      for_site_setting = params[:for_site_setting] == "true"
      is_api = false
      retain_hours = params[:retain_hours].to_i
      type = "composer"
      begin
        info = UploadsController.create_upload(
          current_user: upload_user,
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

      result
    end

    def self.check_upload_image_limit(user_id)
      # 当天日期
      today = Time.now.strftime('%Y-%m-%d')
      redis_key = "loklik_plugin:upload_images:#{user_id}-#{today}"
      max_upload_videos_user_per_day = SiteSetting.max_upload_image_user_per_day
      res = Redis.current.get(redis_key)
      if res && res.to_i >= max_upload_videos_user_per_day
        false
      else
        true
      end
    end

    def self.incr_upload_images_count(user_id)
      today = Time.now.strftime('%Y-%m-%d')
      redis_key = "loklik_plugin:upload_images:#{user_id}-#{today}"

      # 尝试将键的值设为1，如果键不存在
      if Redis.current.setnx(redis_key, 1)
        # 设置过期时间为86400秒（1天）
        Redis.current.expire(redis_key, 86400)
      else
        # 如果键已存在，增加计数
        Redis.current.incr(redis_key)
      end

    end

    def self.get_remaining_upload_images(user_id)
      today = Time.now.strftime('%Y-%m-%d')
      redis_key = "loklik_plugin:upload_images:#{user_id}-#{today}"

      max_upload_images_user_per_day = SiteSetting.max_upload_image_user_per_day
      used_upload_images = Redis.current.get(redis_key).to_i  # key 不存在时返回为 0

      # 计算剩余上传次数
      max_upload_images_user_per_day - used_upload_images
    end

    def self.check_upload_video_limit(user_id)
      # 当天日期
      today = Time.now.strftime('%Y-%m-%d')
      redis_key = "loklik_plugin:upload_videos:#{user_id}-#{today}"
      max_upload_videos_user_per_day = SiteSetting.max_upload_videos_user_per_day
      res = Redis.current.get(redis_key)
      if res && res.to_i >= max_upload_videos_user_per_day
        false
      else
        true
      end
    end

    def self.incr_upload_videos_count(user_id)
      today = Time.now.strftime('%Y-%m-%d')
      redis_key = "loklik_plugin:upload_videos:#{user_id}-#{today}"
      # 尝试将键的值设为1，如果键不存在
      if Redis.current.setnx(redis_key, 1)
        # 设置过期时间为86400秒（1天）
        Redis.current.expire(redis_key, 86400)
      else
        # 如果键已存在，增加计数
        Redis.current.incr(redis_key)
      end
    end

    def self.get_remaining_upload_videos(user_id)
      today = Time.now.strftime('%Y-%m-%d')
      redis_key = "loklik_plugin:upload_videos:#{user_id}-#{today}"

      max_upload_videos_user_per_day = SiteSetting.max_upload_videos_user_per_day
      used_upload_images = Redis.current.get(redis_key).to_i  # key 不存在时返回为 0

      # 计算剩余上传次数
      max_upload_videos_user_per_day - used_upload_images
    end

  end
end

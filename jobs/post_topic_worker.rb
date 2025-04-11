module Jobs
  class PostTopicWorker < Jobs::Base
    sidekiq_options queue: 'low'

    def execute(args)
      LoggerHelper.info args
      params = args
      params[:image] = []

      current_user = User.find_by(id: params[:user_id])
      if current_user.blank?
        raise Discourse::InvalidAccess.new("Invalid user id")
      end

      args[:images] && args[:images].each do |image_url|
        params[:image] << upload_image(current_user, image_url)
      end

      raw = params[:raw] || ""

      raw += HelloModule::PostService.cal_new_post_raw(params[:image], params[:video]) if params[:image] || params[:video]

      manager_params = {}
      manager_params[:raw] = raw
      manager_params[:title] = params[:title]
      manager_params[:category] = params[:category_id]
      manager_params[:first_post_checks] = false
      manager_params[:advance_draft] = false
      # manager_params[:ip_address] = request.remote_ip
      # manager_params[:user_agent] = request.user_agent

      manager = NewPostManager.new(current_user, manager_params).perform
      unless manager.errors.empty?
        LoggerHelper.error "帖子发布失败: #{manager.errors.full_messages}"
        return
      end

      new_topic_id = manager.post.topic_id
      if args[:ext][:work_id].present?
        create_relate_record(current_user.id, new_topic_id, args[:ext][:work_id])
      end

      LoggerHelper.info("帖子发布成功. Topic ID: #{new_topic_id}")
    rescue => e
      LoggerHelper.error "帖子发布异常！"
      LoggerHelper.error(e.full_message)
      raise e
    end

    private
    def create_relate_record(user_id, new_topic_id, work_id)
      app_post_record = HelloModule::AppUserTopicMaterialMap.create(
        user_id: user_id,
        topic_id: new_topic_id,
        external_work_id: work_id,
        )

      unless app_post_record.save
        LoggerHelper.error "创建APP用户-帖子-作品关联记录失败！#{app_post_record.errors.full_messages}"
      end

    end

    def upload_image(current_user, image_url)
      info = UploadsController.create_upload(
        current_user: current_user,
        file: nil,
        url: image_url,
        type: "composer",
        for_private_message: false,
        for_site_setting: false,
        pasted: false,
        is_api: true,
        retain_hours: 0,
        )

      LoggerHelper.info "===图片上传成功==="
      result = UploadsController.serialize_upload(info)
      # LoggerHelper.info result

      {
        "originalName": result["original_filename"],
        "thumbnailWidth": result["thumbnail_width"],
        "thumbnailHeight": result["thumbnail_height"],
        "shortUrl": result["short_url"],
      }
    end

  end
end

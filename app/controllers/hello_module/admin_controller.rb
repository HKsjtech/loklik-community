# frozen_string_literal: true

module ::HelloModule
  class AdminController < ::ApplicationController
    include MyHelper
    include PostHelper
    requires_plugin PLUGIN_NAME
    before_action :set_current_user

    def index
      page = params[:page].to_i > 0 ? params[:page].to_i : 1
      size = params[:size].to_i > 0 ? params[:size].to_i : 10
      search_term = params[:search].presence
      is_curated = params[:is_curated]

      data = AppCuratedTopicService.page_list(search_term, is_curated, page, size)

      render_response(data: data)
    end


    def curated
      topic_id = params[:topic_id]
      is_curated = params[:is_curated]

      curated_topic = AppCuratedTopic.find_by(topic_id: topic_id)

      if curated_topic == nil
        curated_topic = AppCuratedTopic.new(topic_id: topic_id)
      end

      curated_topic.is_curated = is_curated
      curated_topic.update_name = @current_user.username

      if curated_topic.save
        render_response(data: { success: true, curated: curated_topic.is_curated })
      else
        render_response(data: { success: false, errors: curated_topic.errors.full_messages }, code: 400)
      end
    end

    def set_current_user
      @current_user = current_user
    end


    def categories
      res = CategoryService.all(get_request_host)
      render_response(data: res)
    end

    def select_categories
      # limit 3
      acs = AppCategoriesSelected.limit(3).order(sort: :asc)
      data = acs.as_json(only: [:id, :categories_id, :sort])
      render_response(data: data)
    end

    def set_select_categories
      # 从请求中解析 JSON 数据
      data = JSON.parse(request.body.read)

      if data == nil || data.length != 3
        render_response(data: nil, code: 400, msg: '数据不合法')
        return
      end

      data.each do |item|
        id = item['id']
        categories_id = item['categories_id']
        sort = item['sort']

        # 更新 AppCategoriesSelected 模型
        category = AppCategoriesSelected.find_by(id: id)
        if category
          category.update(categories_id: categories_id, sort: sort)
        end
      end

    end

    def upload_image
      # 检查是否有文件上传
      file = params[:file]
      raise "没有上传文件" if file.blank?

      # 检查文件类型
      raise "不支持的文件类型" unless FileHelper.is_supported_image?(file.original_filename)

      result = UploadService.upload_image(file, @current_user, params)
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

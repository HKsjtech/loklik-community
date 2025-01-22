# frozen_string_literal: true

module ::HelloModule
  class AdminController < ::ApplicationController
    include MyHelper
    requires_plugin PLUGIN_NAME
    before_action :set_current_user

    def index
      page = params[:page].to_i > 0 ? params[:page].to_i : 1
      size = params[:size].to_i > 0 ? params[:size].to_i : 10
      is_curated = params[:is_curated]
      offset = (page - 1) * size
      # 获取搜索关键字
      search_term = params[:search].presence

      # 构建查询
      topics_query = Topic.order(created_at: :desc)

      # 如果有搜索关键字，添加模糊搜索条件
      if search_term
        topics_query = topics_query.where("title LIKE ?", "%#{search_term}%")
      end



      # 如果需要根据 is_curated 筛选
      if is_curated == "0" || is_curated == "1"
        # 使用 LEFT JOIN 来确保即使没有匹配的记录也会返回 topics
        topics_query = topics_query.joins("LEFT JOIN app_curated_topic ON app_curated_topic.topic_id = topics.id")

        if is_curated == "1"
          topics_query = topics_query.where("app_curated_topic.is_curated = ?", is_curated)
        else
          # 如果没有筛选条件，确保返回的记录都算作 is_curated 为 false
          topics_query = topics_query.where("app_curated_topic.is_curated IS NULL OR app_curated_topic.is_curated = ?", is_curated)
        end



        # print("==", is_curated)
        # topics_query = topics_query.joins("INNER JOIN app_curated_topic ON app_curated_topic.topic_id = topics.id")
        #                            .where(app_curated_topic: { is_curated: is_curated })
      end

      # 限制结果并进行分页
      topics = topics_query.limit(size).offset(offset)
      total = topics_query.count

      # 查询精选主题数据
      topic_ids = topics.map(&:id)
      curated_topics = AppCuratedTopic.where(topic_id: topic_ids)

      data = topics.map { |topic| serialize_topic(topic, curated_topics) }

      render_response(data: create_page_list(data, total, page, size) )
    end

    def serialize_topic(topic, curated_topics)
      # {
      #    id: 3,
      #    title: '我是标题',
      #    author: 'hosea',
      #    created_at: '2020-01-01 12:00:00',
      #    operator: 'admin',
      #    is_curated: false,
      #    updated_at: '2020-01-01 12:00:00',
      #}
      current_curated_topic = curated_topics.find { |curated_topic| curated_topic.topic_id == topic.id }
      res = {
        id: topic.id,
        title: topic.title,
        author: topic.user.username,
        created_at: topic.created_at,
        is_curated: 0,
        operator: '',
        updated_at: '',
      }
      if current_curated_topic != nil
        res[:is_curated] = current_curated_topic.is_curated
        res[:operator] = current_curated_topic.update_name
        res[:updated_at] = current_curated_topic.updated_at
      end

      res
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

  end
end

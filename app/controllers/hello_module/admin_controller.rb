# frozen_string_literal: true

module ::HelloModule
  class AdminController < ::ApplicationController
    include MyHelper
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

  end
end

# frozen_string_literal: true

module ::HelloModule
  class PostController < ::ApplicationController
    include MyHelper
    requires_plugin PLUGIN_NAME
    skip_before_action :verify_authenticity_token # 跳过认证

    def curated_list
      # todo: need to implement
      render_response(data: { curated_list: 'curated_list' })
    end

    def latest_list
      # todo: need to implement
      render_response(data: { latest_list: 'latest_list' })
    end

    def list_show
      # todo: need to implement
      render_response(data: { latest_list: 'list_show' })
    end

    def show
      # todo: need to implement
      render_response(data: { latest_list: 'show' })
    end

    def comment_list
      # todo: need to implement
      render_response(data: { latest_list: 'comment_list' })
    end

    def topic_comment_list
      # todo: need to implement
      render_response(data: { latest_list: 'topic_comment_list' })
    end

    def topic_collect
      # todo: need to implement
      render_response(data: { latest_list: 'topic_collect' })
    end

    def topic_like
      # todo: need to implement
      render_response(data: { latest_list: 'topic_like' })
    end

    def topic_collect_cancel
      # todo: need to implement
      render_response(data: { latest_list: 'topic_collect_cancel' })
    end

    def topic_like_cancel
      # todo: need to implement
      render_response(data: { latest_list: 'topic_like_cancel' })
    end
  end
end

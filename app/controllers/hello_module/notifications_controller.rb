# frozen_string_literal: true

module ::HelloModule
  class NotificationsController < ::ApplicationController
    include MyHelper
    include DiscourseHelper
    include PostHelper
    requires_plugin PLUGIN_NAME

    skip_before_action :verify_authenticity_token # 跳过认证
    before_action :fetch_current_user

    def unread_count
      #    select count(1) as count from notifications
      #         where notification_type in (2, 5) and user_id = #{userId} and read = false;
      count = Notification.where(notification_type: [2, 5], user_id: @current_user.id, read: false).count
      render_response(data: { count: count })
    end

    def message_list
      res = Notification.where(notification_type: [2, 5], user_id: @current_user.id, read: false)
      render_response(data: res.as_json(only: [:id, :notification_type, :data]))
    end

    def mark_read
      ids = params[:ids]
      Notification.where(id: ids).update_all(read: true)
      render_response
    end

    private
    def fetch_current_user
      user_id = request.env['current_user_id']
      @current_user = User.find_by_id(user_id)
    end
  end
end

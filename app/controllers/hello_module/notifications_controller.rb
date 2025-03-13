# frozen_string_literal: true

module ::HelloModule
  class NotificationsController < CommonController
    include MyHelper
    include DiscourseHelper
    include PostHelper
    include AuthHelper
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
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i


      query = Notification.where(notification_type: [2, 5], user_id: @current_user.id).order(created_at: :desc)

      nos = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      res = nos.map do |n|
        json_data = JSON.parse(n.data)

        user_id = nil
        if n.notification_type == 2   # 评论
          original_post = Post.find_by(id: json_data["original_post_id"])
          if original_post
            post_content = process_text(original_post.raw)[0]
            user_id = original_post.user_id
          end
        elsif n.notification_type == 5  # 点赞
          if n.post_action_id
            pa = PostAction.find_by(id: n.post_action_id)
            user_id = pa.user_id
          end
        end

        user_info = UserService.cal_user_info_by_id(user_id)
        {
          "id": n.id,
          "userId": user_id,
          "name": user_info.name,
          "avatarUrl": user_info.avatar_url,
          "notificationType": n.notification_type,
          "content": post_content,
          "topicId": n.topic_id,
          "title": json_data["topic_title"],
          "read": n.read,
          "sendTime": n.created_at,
          "userIsBlank": user_id.blank?,
          "isLikeTopic": n.post_number == 1
        }
      end

      res.filter! { |n| n.present? } # 去掉 nil

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def mark_read
      ids = params[:ids]
      Notification.where(id: ids).update_all(read: true)
      render_response
    end

    private
    def fetch_current_user
      user_id = get_current_user_id
      @current_user = User.find_by_id(user_id)
    end
  end
end

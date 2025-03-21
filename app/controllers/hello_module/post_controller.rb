# frozen_string_literal: true

module ::HelloModule
  class PostController < CommonController
    include MyHelper
    include PostHelper
    include DiscourseHelper
    include AuthHelper
    requires_plugin PLUGIN_NAME
    skip_before_action :verify_authenticity_token # 跳过认证

    before_action :fetch_current_user

    def curated_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      query = AppCuratedTopic.where(is_curated: 1, is_deleted: 0).order(id: :desc)

      app_curated_topics = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      topic_ids = app_curated_topics.map(&:topic_id)
      res = PostService.cal_topics_by_topic_ids(topic_ids, @current_user.id)

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def latest_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      query = Topic
                 .select('topics.id')
                 .joins('INNER JOIN categories ON topics.category_id = categories.id')
                 .where(deleted_by_id: nil)
                 .where(archetype: 'regular')
                 .where(visible: true)
                 .where(closed: false)
                 .where('categories.read_restricted = false')
                 .order(id: :desc)

      topics = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      res = PostService.cal_topics_by_topic_ids(topics.map(&:id), @current_user.id)

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def list_show
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      category_id = params.require(:category_id)
      query = Topic
                 .select('topics.id')
                 .joins('INNER JOIN categories ON topics.category_id = categories.id')
                 .where(deleted_by_id: nil)
                 .where(archetype: 'regular')
                 .where(visible: true)
                 .where(closed: false)
                 .where('categories.read_restricted = false')
                 .where(category_id: category_id)
                 .order('topics.id DESC')
                 .order(id: :desc)

      topics = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      res = PostService.cal_topics_by_topic_ids(topics.map(&:id), @current_user.id)

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def post_like
      user_id = get_current_user_id
      post_id = (params.require(:post_id)).to_i

      post = Post.find_by_id(post_id)
      if post.nil?
        render_response(code: 404, msg: I18n.t("loklik.post_not_found"), success: false)
        return
      end

      if post.user_id == user_id
        render_response(code: 200, data: 1, success: true) # 0-不是本人 1-是本人
        return
      end

      post_action_type_id = get_action_type_id("like")

      creator =
        PostActionCreator.new(
          @current_user,
          post,
          post_action_type_id,
          )
      result = creator.perform

      return render_response(code: 400, msg: get_operator_msg(result), success: false) if result.errors.any?

      render_response(code: 200, data: 0, success: true) # 0-不是本人 1-是本人
    end

    def post_like_cancel
      user_id = get_current_user_id
      post_id = (params.require(:post_id)).to_i

      post = Post.find_by_id(post_id)
      if post.nil?
        render_response(code: 404, msg: I18n.t("loklik.post_not_found"), success: false)
        return
      end

      if post.user_id == user_id
        render_response(code: 200, data: 1, success: true) # 0-不是本人 1-是本人
        return
      end

      post_action_type = PostActionType.find_by_name_key("like")
      unless post_action_type
        render_response(code: 404, msg: "点赞类型不存在", success: false)
        return
      end
      post_action_type_id = post_action_type.id

      result =
        PostActionDestroyer.new(
          @current_user,
          post,
          post_action_type_id,
          ).perform

      return render_response(code: 400, msg: get_operator_msg(result), success: false) if result.errors.any?

      render_response(code: 200, data: 0, success: true) # 0-不是本人 1-是本人
    end

    private

    def fetch_current_user
      user_id = get_current_user_id
      @current_user = User.find_by_id(user_id)
    end

  end
end


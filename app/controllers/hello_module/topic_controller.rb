# frozen_string_literal: true

module ::HelloModule
  class TopicController < CommonController
    include MyHelper
    include PostHelper
    include DiscourseHelper
    include AuthHelper
    requires_plugin PLUGIN_NAME
    skip_before_action :verify_authenticity_token # 跳过认证

    before_action :fetch_current_user

    def create_topic
      raw = params[:raw]

      raw += PostService.cal_new_post_raw(params[:image], params[:video]) if params[:image] || params[:video]

      manager_params = {}
      manager_params[:raw] = raw
      manager_params[:title] = params[:title]
      manager_params[:category] = params[:categoryId]
      manager_params[:first_post_checks] = false
      manager_params[:advance_draft] = false
      manager_params[:ip_address] = request.remote_ip
      manager_params[:user_agent] = request.user_agent

      manager = NewPostManager.new(@current_user, manager_params)
      res = serialize_data(manager.perform, NewPostResultSerializer, root: false)

      if res && res[:errors] && res[:errors].any?
        return render_response(code: 400, success: false, msg: res[:errors].join(", "))
      end

      new_post_id = res[:post][:id]
      app_post_record = AppPostRecord.create(post_id: new_post_id, is_deleted: 0)

      unless app_post_record.save
        return render_response(code: 500, success: false, msg: I18n.t("loklik.operation_failed"))
      end

      render_response(data: res[:post][:topic_id], success: true, msg: "success")
    end

    def edit_topic
      changes = {}
      changes[:title] = params[:title] if params[:title]
      if params[:raw]
        changes[:raw] = params[:raw]
      end

      if params[:image] || params[:video]
        changes[:raw] = changes[:raw] + PostService.cal_new_post_raw(params[:image], params[:video])
      end

      if changes.none?
        return render_response(code: 400, success: false, msg: I18n.t("loklik.params_error", params: "raw"))
      end

      topic = Topic.find_by(id: params[:topicId].to_i)

      unless topic
        return render_response(code: 400, success: false, msg: I18n.t("loklik.topic_not_found"))
      end

      if  params[:categoryId].present?
        changes[:category_id] = params[:categoryId].to_i
      end

      first_post = topic.ordered_posts.first
      success =
        PostRevisor.new(first_post, topic).revise!(
          @current_user,
          changes,
          validate_post: false,
          bypass_bump: false,
          keep_existing_draft: false,
          )

      return render_response(code: 400, success: false, msg: topic.errors.full_messages.join(", ")) if !success && topic.errors.any?

      render_response
    end

    def destroy_topic
      topic_id = params[:topic_id].to_i

      topic = Topic.find_by(id: topic_id)
      unless topic
        return render_response(msg: I18n.t("loklik.topic_not_found"), code: 404)
      end

      if topic.user_id != @current_user.id
        return render_response(code: 400, success: false, msg: I18n.t("loklik.resource_not_belong_to_you"))
      end

      # 删除 Topic 会有权限问题，先用系统用户删除
      system_user = User.find_by(id: -1)

      guardian = Guardian.new(system_user, request)
      guardian.ensure_can_delete!(topic)

      post = topic.ordered_posts.with_deleted.first
      PostDestroyer.new(
        system_user,
        post,
        context: params[:context],
        force_destroy: false,
        ).destroy

      return render_response(code: 400, success: false, msg: topic.errors.full_messages.join(", ")) if topic.errors.any?

      AppPostRecord.where(post_id: post.id).update_all(is_deleted: 1)

      render_response
    end

    def show
      topic_id = (params.require(:topic_id)).to_i

      topic = Topic.find_by(id: topic_id)
      unless topic
        return render_response(msg: I18n.t("loklik.topic_not_found"), code: 404)
      end

      posts = PostService.cal_topics_by_topic_ids([topic_id], @current_user.id)
      res = posts[0]
      if res.nil?
        return render_response(msg: I18n.t("loklik.topic_not_found"), code: 404)
      end

      is_care = AppUserFollow.where(user_id: @current_user.id, target_user_id: topic.user_id, is_deleted: false).present?
      is_add_category = AppUserCategories.where(user_id: @current_user.id, categories_id: topic.category_id, is_deleted: false).present?

      first_post = topic.ordered_posts.first
      is_app = AppPostRecord.where(post_id: first_post.id, is_deleted: false).present?

      post_action_type_id = get_action_type_id("like")
      like_status = PostAction.where(post_id: first_post.id, post_action_type_id: post_action_type_id, user_id: @current_user.id, deleted_at: nil).exists?

      collect_count = Bookmark.where(bookmarkable_type: 'Topic', bookmarkable_id: topic_id).count
      bookmark_status = Bookmark.where(bookmarkable_type: 'Topic', bookmarkable_id: topic_id, user_id: @current_user.id).exists?

      res["isAuthor"] = topic.user_id == @current_user.id # 是否为作者帖子
      res["isCare"] = is_care # 是否关注作者
      res["isAddCategory"] = is_add_category # 是否加入该分类
      res["isApp"] = is_app # 帖子是否App发布
      res["collectCount"] = collect_count # 收藏数量
      res["likeStatus"] = like_status ? 1 : 0 # 点赞状态 0-否 1-是
      res["bookmarkStatus"] = bookmark_status ? 1 : 0 # 收藏状态 0-否 1-是
      res["firstPostId"] = first_post.id

      render_response(data: res)
    end

    def comment_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      topic_id = params.require(:topic_id)

      select_fields = [
        'posts.id',
        'posts.topic_id',
        'posts.like_count',
        'posts.created_at',
        'posts.reply_count',
        'posts.user_id',
        'posts.raw',
        'posts.created_at',
        'posts.updated_at',
        'posts.post_number',
        'posts.reply_to_post_number',
        'posts.reply_to_user_id',
        'app_user_external_info.surname',
        'app_user_external_info.name',
        'app_user_external_info.avatar_url',
      ]
      query = Post
                  .where(topic_id: topic_id)
                  .where("posts.post_number > 1") # 过滤第一层评论
                  .where("action_code is null") # 过滤系统审核产生的评论
                  .where("posts.reply_to_post_number is null") # 只需要回复帖子的第一层评论
                  .joins('LEFT JOIN app_user_external_info ON posts.user_id = app_user_external_info.user_id')
                  .order(post_number: :desc)

      posts = query.select(select_fields).limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      post_action_type_id = get_action_type_id("like")

      res = posts.map { |p| cal_post(p, post_action_type_id) }

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    # 评论的评论列表
    def comment_comment_list
      topic_id = (params.require(:topic_id)).to_i
      post_number = (params.require(:post_number)).to_i

      select_fields = [
        'posts.id',
        'posts.topic_id',
        'posts.like_count',
        'posts.created_at',
        'posts.reply_count',
        'posts.user_id',
        'posts.raw',
        'posts.created_at',
        'posts.updated_at',
        'posts.post_number',
        'posts.reply_to_post_number',
        'posts.reply_to_user_id',
        'app_user_external_info.surname',
        'app_user_external_info.name',
        'app_user_external_info.avatar_url',
      ]
      post = Post.select(select_fields)
                  .joins('LEFT JOIN app_user_external_info ON posts.user_id = app_user_external_info.user_id')
                  .where(topic_id: topic_id, post_number: post_number)
                  .first
      unless post
        return render_response(msg: I18n.t("loklik.post_not_found"), code: 404)
      end

      all_posts = PostService.find_all_sub_post(topic_id, post_number)

      post_action_type_id = get_action_type_id("like")

      res = all_posts
              .sort! { |a, b| a[:created_at] <=> b[:created_at] }
              .map { |p| cal_post(p, post_action_type_id) }

      render_response(data: res)
    end

    def topic_collect
      topic_id = params[:topic_id].to_i

      topic = Topic.find_by(id: topic_id)
      unless topic
        return render_response(msg: I18n.t("loklik.topic_not_found"), code: 404)
      end

      bookmark_manager = BookmarkManager.new(@current_user)
      bookmark_manager.create_for(bookmarkable_id: topic.id, bookmarkable_type: "Topic")

      return render_response(code: 400, data: nil, msg: get_operator_msg(bookmark_manager), success: false)  if bookmark_manager.errors.any?

      render_response
    end

    def topic_collect_cancel
      topic_id = params[:topic_id].to_i

      topic = Topic.find_by(id: topic_id)
      unless topic
        return render_response(msg: I18n.t("loklik.topic_not_found"), code: 404)
      end

      BookmarkManager.new(@current_user).destroy_for_topic(topic)

      render_response
    end

    private

    def cal_post(post, post_action_type_id)
      new_raw, videos, images = PostService.cal_post_videos_and_images(post.id, post.raw)
      post = serialize_post(post, post_action_type_id)
      post["context"] = new_raw
      post["video"] = videos
      post["image"] = images

      post
    end

    def serialize_post(post, post_action_type_id)
      like_status = PostAction.where(post_id: post.id, post_action_type_id: post_action_type_id, user_id: @current_user.id, deleted_at: nil).exists?
      user_info = UserService.cal_user_info_by_id(post.user_id)

      # 回复人的用户id
      reply_user_id = post.reply_to_user_id
      reply_user_info = UserService.cal_user_info_by_id(reply_user_id) if reply_user_id.present?

      {
        topicId: post.topic_id,
        postId: post.id,
        userId: post.user_id,
        name: user_info.name,
        avatarUrl: user_info.avatar_url,
        openDateTime: post.updated_at,
        postNumber: post.post_number,
        context: post.raw,
        likeCount: post.like_count,
        likeStatus: like_status ? 1 : 0,
        replyCount: post.reply_count,
        replyToPostNumber: post.reply_to_post_number,
        video: [],
        image: [],
        replyUserId: reply_user_id, #回复人的用户id
        replyName: reply_user_info&.name,#回复人的名字
      }
    end

    def fetch_current_user
      user_id = get_current_user_id
      @current_user = User.find_by_id(user_id)
    end

  end
end


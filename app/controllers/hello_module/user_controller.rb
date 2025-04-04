# frozen_string_literal: true

module ::HelloModule
  class UserController < CommonController
    include MyHelper
    include DiscourseHelper
    include PostHelper
    include AuthHelper
    requires_plugin PLUGIN_NAME

    skip_before_action :verify_authenticity_token # 跳过认证
    before_action :fetch_current_user

    def join_category
      user_id = get_current_user_id
      puts "current_user: #{@current_user.id}"
      categories_id = params[:categoriesId]
      # 校验id是否存在
      unless Category.exists?(id: categories_id)
        return render_response(code: 400, success: false, msg: I18n.t("loklik.category_not_found"))
      end

      unless AppUserCategories.upsert({ user_id: user_id, categories_id: categories_id, is_deleted: 0 }, unique_by: [:user_id, :categories_id])
        return render_response(code: 400, success: false, msg: I18n.t("loklik.operation_failed"))
      end

      render_response
    end

    def leave_category
      user_id = get_current_user_id
      categories_id = params[:categoriesId]

      # 校验id是否存在
      unless Category.exists?(id: categories_id)
        return render_response(code: 400, success: false, msg: I18n.t("loklik.category_not_found"))
      end

      user_categories = AppUserCategories.find_by(user_id: user_id, categories_id: categories_id)
      unless  user_categories
        return render_response(code: 400, success: false, msg: I18n.t("loklik.category_not_join"))
      end

      user_categories.is_deleted = 1
      unless user_categories.save
        return render_response(code: 500, success: false, msg: I18n.t("loklik.operation_failed"))
      end

      render_response
    end

    def follow
      user_id = get_current_user_id
      follow_user_id = (params[:userId]).to_i

      ex_user = User.find_by_id(follow_user_id)
      unless ex_user
        return render_response(code: 400, success: false, msg: I18n.t("loklik.user_not_found"))
      end

      if user_id == follow_user_id
        return render_response(code: 400, success: false, msg: I18n.t("loklik.cannot_follow_yourself"))
      end

      # 校验id是否存在
      unless AppUserFollow.upsert({ user_id: user_id, target_user_id: follow_user_id, is_deleted: 0 }, unique_by: [:user_id, :target_user_id])
        return render_response(code: 400, success: false, msg: I18n.t("loklik.operation_failed"))
      end

      render_response
    end

    def cancel_follow
      user_id = get_current_user_id
      follow_user_id = (params[:userId]).to_i

      ex_user = User.find_by_id(follow_user_id)
      unless ex_user
        return render_response(code: 400, success: false, msg: I18n.t("loklik.user_not_found"))
      end

      if user_id == ex_user.id
        return render_response(code: 400, success: false, msg: I18n.t("loklik.cannot_follow_yourself"))
      end

      # 校验id是否存在
      user_follow = AppUserFollow.find_by(user_id: user_id, target_user_id: ex_user.id)
      unless user_follow
        return render_response(code: 400, success: false, msg: I18n.t("loklik.please_follow_user"))
      end

      user_follow.is_deleted = 1
      unless user_follow.save
        return render_response(code: 500, success: false, msg: I18n.t("loklik.operation_failed"))
      end

      render_response
    end

    def fans_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      user_id = get_current_user_id

      # 校验id是否存在
      user = User.find_by(id: user_id)
      unless user
        return render_response(code: 400, success: false, msg: I18n.t("loklik.user_not_found"))
      end

      query = AppUserFollow.where(target_user_id: user_id, is_deleted: 0).order(updated_at: :desc)

      fans_users = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      follow_users = AppUserFollow.where(user_id: user_id, is_deleted: 0)
      follow_user_ids = follow_users.pluck(:target_user_id)

      res = fans_users.map do |fans_user|
        user_info = UserService.cal_user_info_by_id(fans_user.user_id)
        {
          "userId": user_info.user_id, #用户id
          "name": user_info.name, #用户名称
          "avatarUrl": user_info.avatar_url, #用户头像
          "careDateTime": fans_user.updated_at, #关注时间
          "isCare": follow_user_ids.include?(user_info.user_id) #是否关注
        }
      end

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def care_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      user_id = get_current_user_id

      # 校验id是否存在
      user = User.find_by(id: user_id)
      unless user
        return render_response(code: 400, success: false, msg: I18n.t("loklik.user_not_found"))
      end

      query = AppUserFollow.where(user_id: user_id, is_deleted: 0).order(updated_at: :desc)

      care_users = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      fans_users = AppUserFollow.where(target_user_id: user_id, is_deleted: 0)
      fans_user_ids = fans_users.pluck(:user_id)

      res = care_users.to_a.map do |care_user|
        user_info = UserService.cal_user_info_by_id(care_user.target_user_id)
        {
          "userId": user_info.user_id, #用户id
          "name": user_info.name, #用户名称
          "avatarUrl": user_info.avatar_url, #用户头像
          "careDateTime": care_user.updated_at, #关注时间
          "isFans": fans_user_ids.include?(user_info.user_id) #是否关注
        }
      end

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def destroy_post
      post = Post.with_deleted.find_by(id: params[:post_id])
      unless post
        return render_response(code: 400, success: false, msg: I18n.t("loklik.post_not_found"))
      end
      if post.user_id != @current_user.id
        return render_response(code: 400, success: false, msg: I18n.t("loklik.resource_not_belong_to_you"))
      end

      all_posts = PostService.find_all_sub_post(post.topic_id, post.post_number)
      all_posts.concat([post]) # 包含本帖子

      all_posts.each do |p|
        err_msg = PostService.remove_post(p)
        return render_response(code: 400, success: false, msg: err_msg)  if err_msg != nil
      end

      render_response
    end

    def comment
      raw = params[:raw]

      raw += PostService.cal_new_post_raw(params[:image], params[:video]) if params[:image] || params[:video]

      manager_params = {}
      manager_params[:raw] = raw
      manager_params[:topic_id] = params[:topicId]
      manager_params[:archetype] = "regular"
      manager_params[:reply_to_post_number] = params[:replyToPostNumber]
      manager_params[:visible] = true
      manager_params[:image_sizes] = nil
      manager_params[:is_warning] = false
      manager_params[:featured_link] = ""
      manager_params[:ip_address] = request.remote_ip
      manager_params[:user_agent] = request.user_agent
      manager_params[:referrer] = request.referrer
      manager_params[:first_post_checks] = true
      manager_params[:advance_draft] = true

      manager = NewPostManager.new(@current_user, manager_params)
      res = serialize_data(manager.perform, NewPostResultSerializer, root: false)

      if res && res[:errors] && res[:errors].any?
        return render_response(code: 400, success: false, msg: res[:errors].join(", "))
      end

      app_post_record = AppPostRecord.create(post_id: res[:post][:id], is_deleted: 0)

      unless app_post_record.save
        return render_response(code: 500, success: false, msg: I18n.t("loklik.operation_failed"))
      end

      render_response(data: res[:post][:topic_id])
    end

    def report
      post_or_topic_id = (params.require(:id)).to_i # //主题id/帖子id
      is_comment = params.require(:isComment) # 若为true时, id传评论的帖子id；若为false时，id传主题id
      content = params.require(:content) # 举报内容

      if is_comment
        post = Post.find_by_id(post_or_topic_id)
        if post.nil?
          return render_response(code: 404, msg: I18n.t("loklik.post_not_found"), success: false)
        end
      else
        topic = Topic.find_by_id(post_or_topic_id)
        if topic.nil?
          return render_response(code: 404, msg: I18n.t("loklik.topic_not_found"), success: false)
        end
        post = topic.ordered_posts.first
      end

      post_action_type_id = get_action_type_id("notify_moderators")

      creator =
        PostActionCreator.new(
          @current_user,
          post,
          post_action_type_id,
          message: content,
          flag_topic: !is_comment,
          )
      result = creator.perform

      return render_response(code: 400, msg: get_operator_msg(result), success: false) if result.errors.any?

      render_response
    end

    def detail
      user_id = params[:userId].to_i
      if user_id.blank? || user_id == 0
        user =  @current_user
      else
        user = User.find_by_id(user_id)
        if user.blank?
          return render_response(code: 404, msg: I18n.t("loklik.user_not_found"), success: false)
        end
      end

      render_response(data: serialize_user_detail(user))
    end

    def user_topic_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      user_id = params[:userId].to_i

      if user_id.blank? || user_id == 0
        user =  @current_user
      else
        user = User.find_by_id(user_id)
        if user.blank?
          return render_response(code: 404, msg: I18n.t("loklik.user_not_found"), success: false)
        end
      end

      query = Topic
                .select('topics.id')
                .joins('INNER JOIN categories ON topics.category_id = categories.id')
                .where(deleted_by_id: nil)
                .where(archetype: 'regular')
                .where(visible: true)
                .where(closed: false)
                .where(user_id: user.id)
                .where('categories.read_restricted = false')
                .order(created_at: :desc)

      topics = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      res = PostService.cal_topics_by_topic_ids(topics.map(&:id), @current_user.id)

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def like_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      user_id = params[:userId].to_i

      if user_id.blank? || user_id == 0
        user =  @current_user
      else
        user = User.find_by_id(user_id)
        if user.blank?
          return render_response(code: 404, msg: I18n.t("loklik.user_not_found"), success: false)
        end
      end

      # SELECT topics.id, posts.id, post_actions.id
      # FROM "topics"
      #          LEFT JOIN posts ON posts.topic_id = topics.id
      #          LEFT JOIN post_actions ON post_actions.post_id = posts.id
      # WHERE
      #     "topics"."deleted_at" IS NULL AND
      #     (post_actions.user_id = 1 and post_actions.post_action_type_id = 2) AND
      #     (posts.post_number = 1) AND
      #     "topics"."deleted_by_id" IS NULL AND
      #     "topics"."archetype" = 'regular' AND
      #     "topics"."visible" = TRUE AND
      #     "topics"."closed" = FALSE AND
      #     "topics"."category_id" IN (2, 1, 5, 4) ORDER BY "topics"."id" DESC;
      query = Topic
                .select('topics.id')
                .joins('LEFT JOIN posts ON posts.topic_id = topics.id')
                .joins('LEFT JOIN post_actions ON post_actions.post_id = posts.id')
                .where("post_actions.deleted_at IS NULL and post_actions.user_id = ? and post_actions.post_action_type_id = ?", user.id, 2)
                .where("posts.post_number = ?", 1)
                .where(deleted_by_id: nil, archetype: 'regular',visible: true, closed: false, category_id: all_category_ids)
                .order("post_actions.updated_at DESC")

      topics = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      res = PostService.cal_topics_by_topic_ids(topics.map(&:id), @current_user.id)

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def comment_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      topics, total = UserService.comment_list(page_size, current_page, @current_user.id, all_category_ids)

      topic_ids = topics.map do |topic|
        topic["id"]
      end

      res = PostService.cal_topics_by_topic_ids(topic_ids, @current_user.id)

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def collect_topic_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      topics, total = UserService.collect_list(page_size, current_page, @current_user.id, all_category_ids)

      topic_ids = topics.map do |topic|
        topic["id"]
      end

      res = PostService.cal_topics_by_topic_ids(topic_ids, @current_user.id)

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    private

    def serialize_user_detail(user)
      # 关注数量
      care_count = AppUserFollow.where(user_id: user.id, is_deleted: 0).count
      puts care_count
      # 粉丝数量
      fans_count = AppUserFollow.where(target_user_id: user.id, is_deleted: 0).count

      is_care = AppUserFollow.where(user_id: @current_user.id, target_user_id: user.id, is_deleted: 0).exists?

      user_info = UserService.cal_user_info_by_id(user.id)

      {
        "userId": user_info.user_id,#用户id
        "name": user_info.name,#用户名称
        "avatarUrl": user_info.avatar_url,#用户头像
        "isUpgrade": user_info.is_upgrade,#是否升级 0-否 1-是
        "careCount": care_count,#关注数
        "fansCount": fans_count,#粉丝数
        "beLike":  UserService.be_like(user.id),#被点赞数
        "isAuthor": user.id == @current_user.id, # 是否作者 true-是
        "isCare": is_care # 是否关注 true-是
      }
    end

    def fetch_current_user
      user_id = get_current_user_id
      @current_user = User.find_by_id(user_id)
    end

  end
end

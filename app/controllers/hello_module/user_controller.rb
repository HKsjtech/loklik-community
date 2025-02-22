# frozen_string_literal: true

module ::HelloModule
  class UserController < ::ApplicationController
    include MyHelper
    include DiscourseHelper
    include PostHelper
    include AuthHelper
    requires_plugin PLUGIN_NAME

    skip_before_action :verify_authenticity_token # 跳过认证
    before_action :fetch_current_user

    def join_category
      user_id = get_current_user_id

      categories_id = params[:categoriesId]
      # 校验id是否存在
      unless Category.exists?(id: categories_id)
        return render_response(code: 400, success: false, msg: "论坛不存在")
      end

      unless AppUserCategories.upsert({ user_id: user_id, categories_id: categories_id, is_deleted: 0 }, unique_by: [:user_id, :categories_id])
        return render_response(code: 400, success: false, msg: "加入失败")
      end

      render_response
    end

    def leave_category
      user_id = get_current_user_id
      categories_id = params[:categoriesId]

      # 校验id是否存在
      unless Category.exists?(id: categories_id)
        return render_response(code: 400, success: false, msg: "论坛不存在")
      end

      user_categories = AppUserCategories.find_by(user_id: user_id, categories_id: categories_id)
      unless  user_categories
        return render_response(code: 400, success: false, msg: "未加入论坛")
      end

      user_categories.is_deleted = 1
      unless user_categories.save
        return render_response(code: 500, success: false, msg: "退出失败")
      end

      render_response
    end

    def follow
      user_id = get_current_user_id
      follow_user_id = (params[:userId]).to_i

      ex_user = User.find_by_id(follow_user_id)
      unless ex_user
        return render_response(code: 400, success: false, msg: "用户不存在")
      end

      if user_id == follow_user_id
        return render_response(code: 400, success: false, msg: "不能关注自己")
      end

      # 校验id是否存在
      unless AppUserFollow.upsert({ user_id: user_id, target_user_id: follow_user_id, is_deleted: 0 }, unique_by: [:user_id, :target_user_id])
        return render_response(code: 400, success: false, msg: "关注失败")
      end

      render_response
    end

    def cancel_follow
      user_id = get_current_user_id
      follow_user_id = (params[:userId]).to_i

      ex_user = User.find_by_id(follow_user_id)
      unless ex_user
        return render_response(code: 400, success: false, msg: "用户不存在")
      end

      if user_id == ex_user.id
        return render_response(code: 400, success: false, msg: "不能关注自己")
      end

      # 校验id是否存在
      user_follow = AppUserFollow.find_by(user_id: user_id, target_user_id: ex_user.id)
      unless user_follow
        return render_response(code: 400, success: false, msg: "未关注用户")
      end

      user_follow.is_deleted = 1
      unless user_follow.save
        return render_response(code: 500, success: false, msg: "取消关注失败")
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
        return render_response(code: 400, success: false, msg: "用户不存在")
      end

      query = AppUserFollow.where(target_user_id: user_id, is_deleted: 0).order(updated_at: :desc)

      fans_users = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      fans_user_ids = fans_users.pluck(:user_id)

      follow_users = AppUserFollow.where(user_id: user_id, is_deleted: 0)
      follow_user_ids = follow_users.pluck(:target_user_id)

      fans_external_infos = AppUserExternalInfo.where(user_id: fans_user_ids, is_deleted: 0)

      res = fans_users.map do |fans_user|
        user_external_info = fans_external_infos.find_by(user_id: fans_user.user_id)
        unless user_external_info # 用户信息不存在
          next
        end
        user_info = cal_post_user_info(fans_user.user_id, user_external_info)
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
        return render_response(code: 400, success: false, msg: "用户不存在")
      end

      query = AppUserFollow.where(user_id: user_id, is_deleted: 0).order(updated_at: :desc)

      care_users = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      care_user_ids = care_users.pluck(:target_user_id)

      fans_users = AppUserFollow.where(target_user_id: user_id, is_deleted: 0)
      fans_user_ids = fans_users.pluck(:user_id)

      app_user_external_infos = AppUserExternalInfo.where(user_id: care_user_ids, is_deleted: 0)

      res = care_users.to_a.map do |care_user|
        user_external = app_user_external_infos.find_by(user_id: care_user.target_user_id)
        unless user_external
          next
        end

        user_info = cal_post_user_info(user_external.user_id, user_external)
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
        return render_response(code: 400, success: false, msg: "帖子不存在")
      end
      if post.user_id != @current_user.id
        return render_response(code: 400, success: false, msg: "只能删除自己的帖子")
      end
      # 删除 Topic 会有权限问题，先用系统用户删除
      system_user = User.find_by(id: -1)
      guardian = Guardian.new(system_user, request)
      guardian.ensure_can_delete!(post)
      PostDestroyer.new(
        system_user,
        post,
        context: params[:context],
        force_destroy: false,
        ).destroy
      return render_response(code: 400, success: false, msg: post.errors.full_messages.join(", ")) if post.errors.any?
      AppPostRecord.where(post_id: post.id).update_all(is_deleted: 1)

      render_response
    end

    def comment
      min_post_length = SiteSetting.min_post_length || 8
      raw = params[:raw]

      if raw.length < min_post_length
        return render_response(code: 400, success: false, msg: "内容长度不能少于#{min_post_length}个字符")
      end

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


      begin
        manager = NewPostManager.new(@current_user, manager_params)
        res = serialize_data(manager.perform, NewPostResultSerializer, root: false)

        if res && res[:errors] && res[:errors].any?
          return render_response(code: 400, success: false, msg: res[:errors].join(", "))
        end

        app_post_record = AppPostRecord.create(post_id: res[:post][:id], is_deleted: 0)

        unless app_post_record.save
          return render_response(code: 500, success: false, msg: "创建帖子失败")
        end

        render_response(data: res[:post][:topic_id], success: true, msg: "发帖成功")
      rescue => e
        render_response(code: 400, success: false, msg: e.message)
      end
    end

    def report
      post_or_topic_id = (params.require(:id)).to_i # //主题id/帖子id
      is_comment = params.require(:isComment) # 若为true时, id传评论的帖子id；若为false时，id传主题id
      content = params.require(:content) # 举报内容

      if is_comment
        post = Post.find_by_id(post_or_topic_id)
        if post.nil?
          return render_response(code: 404, msg: "帖子不存在", success: false)
        end
      else
        topic = Topic.find_by_id(post_or_topic_id)
        if topic.nil?
          return render_response(code: 404, msg: "主题不存在", success: false)
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
          return render_response(code: 404, msg: "用户不存在", success: false)
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
          return render_response(code: 404, msg: "用户不存在", success: false)
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

      res = PostService.cal_topics_by_topic_ids(topics.map(&:id))

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
          return render_response(code: 404, msg: "用户不存在", success: false)
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
                .where("post_actions.user_id = ? and post_actions.post_action_type_id = ?", user.id, 2)
                .where("posts.post_number = ?", 1)
                .where(deleted_by_id: nil, archetype: 'regular',visible: true, closed: false, category_id: all_category_ids)
                .order("post_actions.updated_at DESC")

      topics = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      res = PostService.cal_topics_by_topic_ids(topics.map(&:id))

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def comment_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      topics, total = UserService.comment_list(page_size, current_page, @current_user.id, all_category_ids)

      topic_ids = topics.map do |topic|
        topic["id"]
      end

      res = PostService.cal_topics_by_topic_ids(topic_ids)

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def collect_topic_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      topics, total = UserService.collect_list(page_size, current_page, @current_user.id, all_category_ids)

      topic_ids = topics.map do |topic|
        topic["id"]
      end

      res = PostService.cal_topics_by_topic_ids(topic_ids)

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

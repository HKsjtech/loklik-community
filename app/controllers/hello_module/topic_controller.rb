# frozen_string_literal: true

module ::HelloModule
  class TopicController < ::ApplicationController
    include MyHelper
    include PostHelper
    include DiscourseHelper
    include AuthHelper
    requires_plugin PLUGIN_NAME
    skip_before_action :verify_authenticity_token # 跳过认证

    before_action :fetch_current_user

    def create_topic
      min_topic_title_length = SiteSetting.min_topic_title_length || 8
      min_post_length = SiteSetting.min_post_length || 8

      title = params[:title]
      raw = params[:raw]

      if title.length < min_topic_title_length
        return render_response(code: 400, success: false, msg: "标题长度不能少于#{min_topic_title_length}个字符")
      end

      if raw.length < min_post_length
        return render_response(code: 400, success: false, msg: "内容长度不能少于#{min_post_length}个字符")
      end

      raw += PostService.cal_new_post_raw(params[:image], params[:video]) if params[:image] || params[:video]

      manager_params = {}
      manager_params[:raw] = raw
      manager_params[:title] = params[:title]
      manager_params[:category] = params[:categoryId]
      manager_params[:first_post_checks] = false
      manager_params[:advance_draft] = false
      manager_params[:ip_address] = request.remote_ip
      manager_params[:user_agent] = request.user_agent

      begin
        manager = NewPostManager.new(@current_user, manager_params)
        res = serialize_data(manager.perform, NewPostResultSerializer, root: false)

        if res && res[:errors] && res[:errors].any?
          return render_response(code: 400, success: false, msg: res[:errors].join(", "))
        end

        new_post_id = res[:post][:id]
        app_post_record = AppPostRecord.create(post_id: new_post_id, is_deleted: 0)

        unless app_post_record.save
          return render_response(code: 500, success: false, msg: "创建帖子失败")
        end

        render_response(data: res[:post][:topic_id], success: true, msg: "发帖成功")

      rescue => e
        render_response(code: 400, success: false, msg: e.message)
      end
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
        return render_response(code: 400, success: false, msg: "没有任何修改")
      end

      topic = Topic.find_by(id: params[:topicId].to_i)

      unless topic
        return render_response(code: 400, success: false, msg: "帖子不存在")
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
      topic = Topic.with_deleted.find_by(id: params[:topic_id])

      unless topic
        return render_response(code: 400, success: false, msg: "帖子不存在")
      end

      if topic.user_id != @current_user.id
        return render_response(code: 400, success: false, msg: "只能删除自己的帖子")
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
    rescue Discourse::InvalidAccess
      render_response(code: 400, success: false, msg: I18n.t("delete_topic_failed"))
    end

    def show
      topic_id = (params.require(:topic_id)).to_i

      topic = Topic.find(topic_id)
      unless topic
        return render_response(msg: "帖子不存在", code: 404)
      end

      posts = PostService.cal_topics_by_topic_ids([topic_id])
      res = posts[0]

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
                  .where("posts.reply_to_post_number is null") # 只需要回复帖子的第一层评论
                  .joins('LEFT JOIN app_user_external_info ON posts.user_id = app_user_external_info.user_id')
                  .order(post_number: :desc)

      posts = query.select(select_fields).limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      post_action_type_id = get_action_type_id("like")

      res = posts.map { |p| cal_post(p, post_action_type_id) }

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    # 评论的回复列表
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
        return render_response(msg: "帖子不存在", code: 404)
      end

      all_posts = []
      tmp_posts = find_reply_post_number_ids(topic_id, [post_number])
      # 如果 posts 不为空， 则循环调用  find_reply_post_number_ids， 直到 posts 为空
      while tmp_posts.present? && tmp_posts.length > 0
        all_posts.concat(tmp_posts)
        post_number_ids = tmp_posts.map(&:post_number)
        tmp_posts = find_reply_post_number_ids(topic_id, post_number_ids)
      end

      post_action_type_id = get_action_type_id("like")

      res = all_posts
              .sort! { |a, b| a[:created_at] <=> b[:created_at] }
              .map { |p| cal_post(p, post_action_type_id) }

      render_response(data: res)
    end

    def topic_collect
      topic = Topic.find(params[:topic_id].to_i)

      bookmark_manager = BookmarkManager.new(@current_user)
      bookmark_manager.create_for(bookmarkable_id: topic.id, bookmarkable_type: "Topic")

      return render_response(code: 400, data: nil, msg: get_operator_msg(bookmark_manager), success: false)  if bookmark_manager.errors.any?

      render_response
    end

    def topic_collect_cancel
      params.require(:topic_id)

      topic = Topic.find(params[:topic_id].to_i)
      BookmarkManager.new(@current_user).destroy_for_topic(topic)

      render_response
    end

    private

    def find_reply_post_number_ids(topic_id, post_number_ids)
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
      Post.select(select_fields)
                 .where(topic_id: topic_id, reply_to_post_number: post_number_ids)
                 .joins('LEFT JOIN app_user_external_info ON posts.user_id = app_user_external_info.user_id')
          .order(created_at: :asc)
    end
    def cal_topics_by_topic_ids(topic_ids)
      res = serialize_topic(topic_ids)

      # 如果需要将结果转换为 JSON 字符串
      res.each do |topic|
        post = Post.where(topic_id: topic[:id], post_number: 1).first
        new_raw, videos, images = cal_post_videos_and_images(post.id, post.raw)
        topic["context"] = new_raw
        topic["video"] = videos
        topic["image"] = images
      end

      res

    end

    def serialize_topic(topic_ids)
      select_fields = [
        'topics.id',
        'topics.user_id',
        'app_user_external_info.name',
        'app_user_external_info.avatar_url',
        #'to_char(topics.created_at, \'YYYY-MM-DD HH24:MI:SS\') as open_date_time',
        'topics.created_at as open_date_time',
        'topics.title',
        'topics.excerpt as context',
        '(topics.posts_count - 1) as comment_count',
        '(SELECT SUM(like_count) FROM posts WHERE topic_id = topics.id AND post_number = 1) as like_count'
      ]

      topics = Topic
                 .select(select_fields)
                 .joins('LEFT JOIN app_user_external_info ON topics.user_id = app_user_external_info.user_id')
                 .joins('INNER JOIN categories ON topics.category_id = categories.id')
                 .where(deleted_by_id: nil)
                 .where(archetype: 'regular')
                 .where(visible: true)
                 .where(closed: false)
                 .where('categories.read_restricted = false')
                 .where(id: topic_ids)
                 .order('topics.id DESC')

     topics.map do |topic|
        {
          id: topic.id, # 主题id
          userId: topic.user_id, # 用户id
          name: topic.name, # 用户名称
          avatarUrl: topic.avatar_url, # 用户头像
          openDateTime: topic.open_date_time, # 发布时间格式化
          title: topic.title, # 标题
          context: topic.context, # 内容
          likeCount: topic.like_count, # 点赞数量
          commentCount: topic.comment_count # 评论数量
        }
      end
    end

    def cal_post_videos_and_images(post_id, post_row)
      new_raw, video_links = process_text(post_row)
      # 计算 video
      app_video_uploads = AppVideoUpload.where(url: video_links)
      ordered_videos = video_links.map { |link| app_video_uploads.find { |video| video.url == link } }
      #
      videos = ordered_videos
                 .filter { |video| video.present? } # http连接可能找不到上传记录  需要过滤掉
                 .map do |video|
        {
          "url": format_url(video["url"]),
          "coverImg": format_url(video["cover_img"]),
          "thumbnailWidth": video["thumbnail_width"],
          "thumbnailHeight": video["thumbnail_height"],
        }
      end

      select_fields2 = [
        'posts.topic_id as topic_id',
        'posts.raw as raw',
        'posts.post_number as post_number',
        'uploads.id as upload_id',
        'uploads.url as url',
        'uploads.original_filename as original_filename',
        'uploads.thumbnail_width as thumbnail_width',
        'uploads.thumbnail_height as thumbnail_height'
      ]

      # 计算 images
      post_uploads = Post
                       .select(select_fields2)
                       .joins('LEFT JOIN upload_references urs ON posts.id = urs.target_id AND urs.target_type = \'Post\'')
                       .joins('LEFT JOIN uploads ON uploads.id = urs.upload_id')
                       .where(id: post_id)


      images = post_uploads
                 .filter { |upload| upload["url"].present? } # 没有上传时也会查询出一条空记录，需要过滤掉
                 .map do |item|
        item_url = item["url"]
        url = "https:#{item_url}" if item_url && item_url.start_with?("//")
        {
          id: item["upload_id"],
          url: url,
          originalName: item["original_filename"],
          thumbnailWidth: item["thumbnail_width"],
          thumbnailHeight: item["thumbnail_height"],
          shortUrl: item["short_url"], # todo: need to implement
        }
      end

      [new_raw, videos, images]
    end

    def cal_post(post, post_action_type_id)
      new_raw, videos, images = cal_post_videos_and_images(post.id, post.raw)
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
        openDateTime: post.created_at,
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


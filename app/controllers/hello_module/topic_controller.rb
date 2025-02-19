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

    def show
      topic_id = params.require(:topic_id)

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
        'app_user_external_info.surname',
        'app_user_external_info.name',
        'app_user_external_info.avatar_url',
      ]
      query = Post.select(select_fields)
                  .where(topic_id: topic_id)
                  .where("posts.post_number > 1") # 过滤第一层评论
                  .where("posts.reply_to_post_number is null") # 只需要回复帖子的第一层评论
                  .joins('LEFT JOIN app_user_external_info ON posts.user_id = app_user_external_info.user_id')
                  .order(post_number: :asc)
      posts = query.limit(page_size).offset(current_page * page_size - page_size)
      total = posts.count

      post_action_type_id = get_action_type_id("like")

      res = posts.map { |p| cal_post(p, post_action_type_id) }

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    # 获取帖子详情评论下的评论列表
    def post_show
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
      tmp_posts = find_reply_post_number_ids(topic_id, [post.id])
      # 如果 posts 不为空， 则循环调用  find_reply_post_number_ids， 直到 posts 为空
      while tmp_posts.present? && tmp_posts.length > 0
        post_number_ids = tmp_posts.map(&:post_number)
        tmp_posts = find_reply_post_number_ids(topic_id, post_number_ids)
        all_posts.concat(tmp_posts)
      end

      post_action_type_id = get_action_type_id("like")

      res = all_posts.map { |p| cal_post(p, post_action_type_id) }

      render_response(data: res)
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
      {
        topicId: post.topic_id,
        postId: post.id,
        userId: post.user_id,
        name: post.surname + post.name,
        avatarUrl: post.avatar_url,
        openDateTime: post.created_at,
        postNumber: post.post_number,
        context: post.raw,
        likeCount: post.like_count,
        likeStatus: like_status ? 1 : 0,
        replyCount: post.reply_count,
        replyToPostNumber: post.reply_to_post_number,
        video: [],
        image: []
      }
    end

    def fetch_current_user
      user_id = get_current_user_id
      @current_user = User.find_by_id(user_id)
    end

  end
end


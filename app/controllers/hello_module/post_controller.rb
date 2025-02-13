# frozen_string_literal: true

module ::HelloModule
  class PostController < ::ApplicationController
    include MyHelper
    include PostHelper
    requires_plugin PLUGIN_NAME
    skip_before_action :verify_authenticity_token # 跳过认证

    before_action :fetch_current_user, only: [:post_like, :post_like_cancel, :topic_collect, :topic_collect_cancel]

    def curated_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      query = AppCuratedTopic.where(is_curated: 1, is_deleted: 0).order(id: :desc)

      app_curated_topics = query.limit(page_size).offset(current_page * page_size - page_size)
      total = query.count

      topic_ids = app_curated_topics.map(&:topic_id)
      res = cal_topics_by_topic_ids(topic_ids)

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

      res = cal_topics_by_topic_ids(topics.map(&:id))

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

      res = cal_topics_by_topic_ids(topics.map(&:id))

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def show
      topic_id = params.require(:topic_id)

      res = cal_topics_by_topic_ids([topic_id])
      topic = res[0]

      # todo: need to implement
      # "isAuthor": false,//是否为作者帖子
      # "isCare": false,//是否关注作者
      # "isAddCategory": false,//是否加入该分类
      # "isApp": true,//帖子是否App发布
      # "collectCount": 999,//收藏数量
      # "likeStatus": 0,//点赞状态 0-否 1-是
      # "bookmarkStatus": 0//收藏状态 0-否 1-是
      topic["isAuthor"] = false
      topic["isCare"] = false
      topic["isAddCategory"] = false
      topic["isApp"] = true
      topic["collectCount"] = 999
      topic["likeStatus"] = 0
      topic["bookmarkStatus"] = 0

      render_response(data: topic)
    end

    def comment_list
      current_page = (params[:currentPage] || 1).to_i
      page_size = (params[:pageSize] || 10).to_i

      topic_id = params.require(:topic_id)

      query = Post.where(topic_id: topic_id, post_number: 2).order(id: :desc)
      posts = query.limit(page_size).offset(current_page * page_size - page_size)
      total = posts.count

      res = posts.map do |p|
        new_raw, videos, images = cal_post_videos_and_images(p.id, p.raw)
        post = seralize_post(p)
        post["context"] = new_raw
        post["videos"] = videos
        post["images"] = images
        post
      end

      render_response(data: create_page_list(res, total, current_page, page_size ))
    end

    def topic_comment_list
      # todo: need to implement
      render_response(data: { latest_list: 'topic_comment_list' })
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

    def post_like
      # current_user
      user_id = request.env['current_user_id']
      post_id = (params.require(:post_id)).to_i

      post = Post.find_by_id(post_id)
      if post.nil?
        render_response(code: 404, msg: "帖子不存在", success: false)
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
      user_id = request.env['current_user_id']
      post_id = (params.require(:post_id)).to_i

      post = Post.find_by_id(post_id)
      if post.nil?
        render_response(code: 404, msg: "帖子不存在", success: false)
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
    def cal_topics_by_topic_ids(topic_ids)
      res = serlize_topic(topic_ids)

      # 如果需要将结果转换为 JSON 字符串
      res.each do |topic|
        post = Post.where(topic_id: topic[:id], post_number: 1).first
        new_raw, videos, images = cal_post_videos_and_images(post.id, post.raw)
        topic["context"] = new_raw
        topic["videos"] = videos
        topic["images"] = images
      end

      res

    end

    def serlize_topic(topic_ids)
      select_fields = [
        'topics.id',
        'topics.user_id',
        'app_user_external_info.name',
        'app_user_external_info.avatar_url',
        'to_char(topics.created_at, \'YYYY-MM-DD HH24:MI:SS\') as open_date_time',
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
          id: topic.id.to_s, # 主题id，转为字符串
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
          "url": video["url"],
          "coverImg": video["cover_img"],
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

    def seralize_post(post)
      #  "topicId": 1,//主题id
      #     "postId": 1,//帖子id
      #     "userId": 3,//用户id
      #     "name": "test",//用户名称
      #     "avatarUrl": "http://sfs",//用户头像
      #     "openDateTime": "2024-12-02 00:00:00",//发布时间
      #     "postNumber": 2,//帖子编号 **回复根据该编号进行操作**
      #     "context": "fjksdfnkjs",//评论内容
      #     "likeCount": 20,//点赞数量
      #     "likeStatus": 0,//点赞状态 0-否 1-是
      #     "replyCount": 3,//当前回复下的回复数量
      {
        topicId: post.topic_id,
        postId: post.id,
        userId: post.user_id,
        name: "",
        avatarUrl: "",
        openDateTime: "",
        postNumber: post.post_number,
        context: post.raw,
        likeCount: post.like_count,
        likeStatus: 0,
        replyCount: 0,
        videos: [],
        images: []
      }
    end

    def fetch_current_user
      user_id = request.env['current_user_id']
      @current_user = User.find_by_id(user_id)
    end

    def get_operator_msg(result)
      result.errors.full_messages.join(", ")
    end

  end
end


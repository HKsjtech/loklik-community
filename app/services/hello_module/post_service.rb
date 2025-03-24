module ::HelloModule
  class PostService
    extend PostHelper
    extend DiscourseHelper

    def self.cal_topics_by_topic_ids(topic_ids, user_id)
      cal_topics = serialize_topic(topic_ids, user_id)

      # 如果需要将结果转换为 JSON 字符串
      cal_topics.each do |topic|
        post = Post.where(topic_id: topic[:id], post_number: 1).first
        new_raw, videos, images = PostService.cal_post_videos_and_images(post.id, post.raw)
        topic["context"] = new_raw
        topic["video"] = videos
        topic["image"] = images
      end

      # 保持排序一致
      res = topic_ids.map do |topic_id|
        cal_topics.find { |t| t[:id] == topic_id }
      end

      res = res.filter { |t| t.present? } # 过滤掉空结果

      res
    end

    def self.cal_new_post_raw(images, video)
      res = ""

      # 图片
      if images.present?
        images.each do |image|
          # ![1831162626387005440|645x475](upload://3yV3pjc9HkuEhvmX5dcYw2JBI8f.jpeg)
          origin_file_name = remove_file_ext(image[:originalName])
          res += "\n![#{origin_file_name}|#{image[:thumbnailWidth]}x#{image[:thumbnailHeight]}](#{image[:shortUrl]})"
        end
      end

      # 视频
      res += "\n\n#{video}" if video

      res
    end

    def self.cal_post_videos_and_images(post_id, post_row)
      new_raw, video_links, image_lines = process_text(post_row)
      # 计算 video
      app_video_uploads = AppVideoUpload.where(url: video_links)
      ordered_videos = video_links.map { |link| app_video_uploads.find { |video| video.url == link } }

      # 找到在 video_links 中但不在 app_video_uploads 中的链接
      white_links = video_links.filter do |link|
        !app_video_uploads.any? { |video| video.url == link }
      end

      if white_links.length > 0
        new_raw = gen_new_row(post_row, white_links) # 如果链接不是app上传的视频就不要去掉
      end

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

      # select_fields2 = [
      #   'posts.topic_id as topic_id',
      #   'posts.raw as raw',
      #   'posts.post_number as post_number',
      #   'uploads.id as upload_id',
      #   'uploads.url as url',
      #   'uploads.original_filename as original_filename',
      #   'uploads.thumbnail_width as thumbnail_width',
      #   'uploads.thumbnail_height as thumbnail_height'
      # ]

      # # 计算 images
      # post_uploads = Post
      #                  .select(select_fields2)
      #                  .joins('LEFT JOIN upload_references urs ON posts.id = urs.target_id AND urs.target_type = \'Post\'')
      #                  .joins('LEFT JOIN uploads ON uploads.id = urs.upload_id')
      #                  .where(id: post_id)
      #                  .order('uploads.updated_at DESC')
      # post_uploads = post_uploads
      #   .filter { |upload| upload["url"].present? } # 没有上传时也会查询出一条空记录，需要过滤掉

      images = []
      web_uploads = []
      image_lines.each do |line|
        # real_filename = extract_identifier(line)
        # next if real_filename == ""
        # post_upload = post_uploads.find { |upload| remove_file_ext(upload["original_filename"]) == real_filename }
        # if post_upload.present?
        #   if post_upload["thumbnail_width"].present? && post_upload["thumbnail_height"].present?
        #     short_url = find_upload_url(image_lines, remove_file_ext(post_upload["original_filename"]))
        #     images <<  {
        #       id: post_upload["upload_id"],
        #       url: format_url(post_upload["url"]),
        #       originalName: post_upload["original_filename"],
        #       thumbnailWidth: post_upload["thumbnail_width"],
        #       thumbnailHeight: post_upload["thumbnail_height"],
        #       shortUrl: short_url,
        #     }
        #   else
        #     web_uploads << format_url(post_upload["url"])
        #   end
        # end
        short_url = extract_image_short_link(line)
        upload_sha1 = Upload.sha1_from_short_url(short_url)
        uploads_by_sha1 = Upload.where(sha1: upload_sha1).first
        next if uploads_by_sha1.nil?
        upload_id = uploads_by_sha1.id
        upload_url = upload_id ?  uploads_by_sha1.url : nil
        cdn_url = upload_url ? Discourse.store.cdn_url(upload_url) : ""

        if uploads_by_sha1.thumbnail_width.present? && uploads_by_sha1.thumbnail_height.present?
          images <<  {
            id: uploads_by_sha1.id,
            url: cdn_url,
            originalName: uploads_by_sha1.original_filename,
            thumbnailWidth: uploads_by_sha1.thumbnail_width,
            thumbnailHeight: uploads_by_sha1.thumbnail_height,
            shortUrl: short_url,
          }
        else
          web_uploads << format_url(uploads_by_sha1.url)
        end
      end

      # 处理单独上传视频的场景（历史数据，后面会移除上传按钮）
      if web_uploads.length > 0
        new_raw += "\n\n#{web_uploads.join("\n")}"
      end

      # 处理上传视频和封面图组件的场景
      new_raw, handle_videos = handle_video_cover(new_raw)
      videos.concat(handle_videos) # 视频合并在一起

      [new_raw, videos, images]
    end

    def self.serialize_topic(topic_ids, user_id)
      select_fields = [
        'topics.id',
        'topics.user_id',
        'topics.category_id as category_id',
        'app_user_external_info.name',
        'app_user_external_info.surname',
        'app_user_external_info.avatar_url',
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
        user_info = UserService.cal_user_info_by_id(topic.user_id)
        first_post = Post.where(topic_id: topic.id, post_number: 1).first
        comment_count = Post
                          .where(topic_id: topic.id)
                          .where("posts.post_number > 1") # 过滤第一层评论
                          .where("action_code is null") # 过滤系统审核产生的评论
                          .count
        # open_date_time = topic.updated_at > first_post.updated_at ? topic.updated_at : first_post.updated_at # 发布时间格式化
        {
          id: topic.id, # 主题id
          userId: topic.user_id, # 用户id
          name: user_info.name, # 用户名称
          avatarUrl: user_info.avatar_url, # 用户头像
          category: topic.category_id,
          openDateTime: topic.open_date_time, # 发布时间格式化
          title: topic.title, # 标题
          context: topic.context, # 内容
          likeCount: topic.like_count, # 点赞数量
          commentCount: comment_count, # 评论数量
          likeStatus: cal_topic_like_status(user_id, topic.id), # 点赞状态 0-否 1-是
          firstPostId: first_post&.id,
        }
      end
    end

    def self.extract_identifier(markdown_str)
      # 使用正则表达式匹配 Markdown 图片的 alt 部分
      # ![image_picker_3A9A59BC-8B84-4060-9502-3B19E9173891-19280-000A7E1ACB12E080|334x500](upload://k9KOfedX2rFargvxXzlxfTprIip.jpeg)
      alt_part = markdown_str.match(/!\[([^\|\]]+)(?:\|.*?)?\]/x)&.captures&.first

      unless alt_part
        LoggerHelper.error("markdown_str: #{markdown_str}")
      end

      # 返回匹配结果或抛出异常
      alt_part
    end

    def self.extract_image_short_link(text)
      # 正则表达式匹配 upload:// 开头的短链接
      regex = /upload:\/\/[^\s)]+/

      # 使用正则表达式查找匹配的短链接
      match = text.match(regex)

      # 如果找到匹配，返回结果，否则返回 nil
      match ? match[0] : nil
    end

    # 找到一个评论所有的子评论
    def self.find_all_sub_post(topic_id, post_number)
      all_posts = []
      tmp_posts = find_reply_post_number_ids(topic_id, [post_number])
      # 如果 posts 不为空， 则循环调用  find_reply_post_number_ids， 直到 posts 为空
      while tmp_posts.present? && tmp_posts.length > 0
        all_posts.concat(tmp_posts)
        post_number_ids = tmp_posts.map(&:post_number)
        tmp_posts = find_reply_post_number_ids(topic_id, post_number_ids)
      end
      all_posts
    end

    def self.remove_post(post)
      post = Post.with_deleted.find_by(id: post.id)
      # 删除 Topic 会有权限问题，先用系统用户删除
      system_user = User.find_by(id: -1)
      # guardian = Guardian.new(system_user, request)
      # guardian.ensure_can_delete!(post)
      PostDestroyer.new(
        system_user,
        post,
        context: nil,
        force_destroy: false,
        ).destroy
      if post.errors.any?
        LoggerHelper.error("remove_post error: #{get_operator_msg(post)}")
        return get_operator_msg(post)
      end
      AppPostRecord.where(post_id: post.id).update_all(is_deleted: 1)
      nil
    end

    def self.cal_topic_like_status(user_id, topic_id)
      post = Post.where(topic_id: topic_id, post_number: 1).first
      post_action_type_id = get_action_type_id("like")
      like_status = PostAction.where(post_id: post.id, post_action_type_id: post_action_type_id, user_id: user_id, deleted_at: nil).exists?
      like_status ? 1 : 0 # 点赞状态 0-否 1-是
    end

    private
    def self.find_reply_post_number_ids(topic_id, post_number_ids)
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

    # 处理 video 标签的视频
    def self.handle_video_cover(text)
      # 用于存储提取出的链接
      videos_info = []

      # 匹配所有的 <video> 标签，处理可选的 poster 和 src 属性
      text.gsub!(/<video.*?((poster="(.*?)"\s+)?)(.*?)>(.*?)<\/video>/m) do |match|
        # 提取 poster 链接，如果存在的话
        poster = match.match(/poster="(.*?)"/)&.[](1)

        # 提取 src 链接，如果存在的话
        src = match.match(/<source src="(.*?)"/)&.[](1)

        # 将提取的信息存入数组
        videos_info << {
          "url": src,
          "coverImg": poster,
          "thumbnailWidth": nil,
          "thumbnailHeight": nil
        }

        # 返回空字符串以去掉整个 video 标签
        ''
      end

      [text.strip, videos_info]
    end
  end
end

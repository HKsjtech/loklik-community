module ::HelloModule
  class PostService
    extend PostHelper

    def self.cal_topics_by_topic_ids(topic_ids)
      cal_topics = serialize_topic(topic_ids)

      # 如果需要将结果转换为 JSON 字符串
      cal_topics.each do |topic|
        post = Post.where(topic_id: topic[:id], post_number: 1).first
        new_raw, videos, images = cal_post_videos_and_images(post.id, post.raw)
        topic["context"] = new_raw
        topic["video"] = videos
        topic["image"] = images
      end

      # 保持排序一致
      res = topic_ids.map do |topic_id|
        cal_topics.find { |t| t[:id] == topic_id }
      end

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


    private

    def self.cal_post_videos_and_images(post_id, post_row)
      new_raw, video_links, image_lines = process_text(post_row)
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
                       .order('uploads.updated_at DESC')
      post_uploads = post_uploads
        .filter { |upload| upload["url"].present? } # 没有上传时也会查询出一条空记录，需要过滤掉

      images = []
      image_lines.each do |line|
        real_filename = extract_identifier(line)
        if real_filename == ""
          next
        end
        post_upload = post_uploads.find { |upload| remove_file_ext(upload["original_filename"]) == real_filename }
        if post_upload.present?
          short_url = find_upload_url(image_lines, remove_file_ext(post_upload["original_filename"]))
          images <<  {
            id: post_upload["upload_id"],
            url: format_url(post_upload["url"]),
            originalName: post_upload["original_filename"],
            thumbnailWidth: post_upload["thumbnail_width"],
            thumbnailHeight: post_upload["thumbnail_height"],
            shortUrl: short_url,
          }
        end
      end

      [new_raw, videos, images]
    end


    def self.serialize_topic(topic_ids)
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
        user_info = cal_post_user_info(topic.user_id, topic)

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
          commentCount: topic.comment_count # 评论数量
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

  end
end

require 'ostruct'
module PostHelper
  def process_text(input_text)
    return [input_text, [], []] if input_text.blank?
    # 按行分割文本
    lines = input_text.split("\n")

    video_link_lines = lines.filter do |line|
      line.strip.start_with?('http:', 'https:')
    end

    # 处理后的结果
    images_lines = lines.filter do |line|
      # 去掉图片行（包含 ![ 和 ]( 的行）
      line.match?(/!\[.*\]\(.*\)/)
    end

    lines = lines.filter do |line|
      # 去掉视频链接行
      line.strip.start_with?('http:', 'https:') == false &&
      # 去掉图片行
      line.match?(/!\[.*\]\(.*\)/) == false
    end

    # 返回处理后的文本，按行连接
    text = lines.join("\n")

    [remove_markdown(text), video_link_lines, images_lines]
  end

   def gen_new_row(input_text, white_links)
    # 按行分割文本
    lines = input_text.split("\n")

    lines = lines.filter do |line|
      # 如果是视频链接行，检查是否在白名单中
      if line.strip.start_with?('http:', 'https:')
        white_links.include?(line.strip)
      else
        # 去掉图片行
        !line.match?(/!\[.*\]\(.*\)/)
      end
    end

    # 返回处理后的文本，按行连接
    text = lines.join("\n")

    remove_markdown(text)
  end

  def remove_markdown(text)
    # 去掉多行代码块（```)
    text.gsub!(/```.*?```/m, '')  # ```code```

    # 去掉标题（#、##、### 等）
    text.gsub!(/#+\s*/, '')

    # 去掉粗体（** 和 __）
    text.gsub!(/\*\*(.*?)\*\*/, '\1')  # **text**
    text.gsub!(/__(.*?)__/, '\1')      # __text__

    # 去掉斜体（* 和 _）
    text.gsub!(/\*(.*?)\*/, '\1')      # *text*
    text.gsub!(/_(.*?)_/, '\1')        # _text_

    # 去掉链接（[text](url)）
    text.gsub!(/\[(.*?)\]\(.*?\)/, '\1') # [text](url)

    # 去掉图片（![alt](url)）
    text.gsub!(/!\[.*?\]\(.*?\)/, '')   # ![alt](url)

    # 去掉列表符号（*、-、+ 等）
    text.gsub!(/^[\*\-\+] +/, '')

    # 去掉代码块（`code`）
    text.gsub!(/`([^`]+)`/, '\1')       # `code`

    # 去掉换行符后多余的空格
    text.gsub!(/\s+$/, '')

    # 返回处理后的文本
    text.strip
  end

  def remove_html_tags(text)
    return text if text.blank?
    text.gsub(/<\/?[^>]*>/, '')
  end

  def get_action_type_id(name_key)
    post_action_type = PostActionType.find_by_name_key(name_key)
    unless post_action_type
      LoggerHelper.error("PostActionType not found: like")
      raise "PostActionType not found: like"
    end
    post_action_type.id
  end

  def all_category_ids
     Category.where(read_restricted: false).pluck(:id)
  end

  def all_category_topic_ids
    Category.all.pluck(:topic_id)
  end

  def format_url(url)
    if url == "" || url.nil?
      return ""
    end
    url = Discourse.store.cdn_url(url)
    if url.start_with?('http')
      url
    elsif url.start_with?('//')
      "https:#{url}"
    elsif url.start_with?('/')
      "#{Discourse.base_url}#{url}"
    else
      url
    end
  end

  # 移除文件扩展名
  def remove_file_ext(filename)
    File.basename(filename, File.extname(filename))
  end

  # 找到 Markdown 图片语法中的指定文件名对应的 URL
  def find_upload_url(markdown_images, target_filename)
    # 构建文件名到URL的映射哈希（带缓存）
    # 查找对应的元素
    result = markdown_images.find do |image|
      image.include?(target_filename)
    end

    # 提取对应的 upload URL
    upload_url = result.match(/(upload:\/\/[^\)]+)/)[1] if result

    upload_url
  end
end

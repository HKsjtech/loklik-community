module PostHelper
  def process_text(input_text)
    # 按行分割文本
    lines = input_text.split("\n")

    video_link_lines = lines.filter do |line|
      # 去掉视频链接行（以 http 或 https 开头的行）
      line.strip.start_with?('http:', 'https:')
    end

    # 处理后的结果
    processed_lines = lines.reject do |line|
      # 去掉图片行（包含 ![ 和 ]( 的行）
      line.match?(/!\[.*\]\(.*\)/) ||
      # 去掉视频链接行（以 https 开头的行）
      line.start_with?('https:')
    end

    # 返回处理后的文本，按行连接
    text =processed_lines.join("\n")

    [remove_markdown(text), video_link_lines]
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
end

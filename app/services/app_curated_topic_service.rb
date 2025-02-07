class AppCuratedTopicService
  extend MyHelper

  def self.serialize_topic(topic, curated_topics)
    current_curated_topic = curated_topics.find { |curated_topic| curated_topic.topic_id == topic.id }
    res = {
      id: topic.id,
      title: topic.title,
      author: topic.user.username,
      created_at: topic.created_at,
      is_curated: 0,
      operator: '',
      updated_at: '',
    }
    if current_curated_topic != nil
      res[:is_curated] = current_curated_topic.is_curated
      res[:operator] = current_curated_topic.update_name
      res[:updated_at] = current_curated_topic.updated_at
    end
    res
  end

  def self.page_list(search_term, is_curated, page, size)
    offset = (page - 1) * size

    # 构建查询
    topics_query = Topic.where(deleted_by_id: nil, archetype: 'regular',visible: true, closed: false).order(created_at: :desc)
    # todo: 筛选 category.read_restricted = false

    # 如果有搜索关键字，添加模糊搜索条件
    if search_term
      topics_query = topics_query.where("title LIKE ?", "%#{search_term}%")
    end

    # 如果需要根据 is_curated 筛选
    if is_curated == "0" || is_curated == "1"
      # 使用 LEFT JOIN 来确保即使没有匹配的记录也会返回 topics
      topics_query = topics_query.joins("LEFT JOIN app_curated_topic ON app_curated_topic.topic_id = topics.id")

      if is_curated == "1"
        topics_query = topics_query.where("app_curated_topic.is_curated = ?", is_curated)
      else
        # 如果没有筛选条件，确保返回的记录都算作 is_curated 为 false
        topics_query = topics_query.where("app_curated_topic.is_curated IS NULL OR app_curated_topic.is_curated = ?", is_curated)
      end
    end

    # 限制结果并进行分页
    topics = topics_query.limit(size).offset(offset)
    total = topics_query.count

    # 查询精选主题数据
    topic_ids = topics.map(&:id)
    curated_topics = HelloModule::AppCuratedTopic.where(topic_id: topic_ids)

    data = topics.map { |topic| serialize_topic(topic, curated_topics) }

    create_page_list(data, total, page, size)
  end

end

class UserService
  def self.be_like(user_id)
    # 被点赞数量
    sql = "select case when sum(p.like_count) is null then 0 else sum(p.like_count) end
from topics t
    join posts p on t.id = p.topic_id
where
    t.deleted_by_id is null and
    t.archetype = 'regular' and
    t.visible = true and
    t.closed = false and
    p.deleted_by_id is null and
    p.hidden = false and
    p.user_id = #{user_id} and
    p.post_number = 1"
    result = ActiveRecord::Base.connection.execute(sql)

    result.first["sum"]
  end

  def self.comment_list(page_size, current_page, user_id, category_ids)
    category_ids = category_ids.join(",")
    # 被点赞数量
    sql = "select t.id, t.user_id, auei.name,auei.avatar_url, to_char(t.created_at, 'YYYY-MM-DD HH24:MI:SS') as open_date_time,
       t.title, t.excerpt as context, (t.posts_count -1) as comment_count,
       (select sum(like_count) from posts where topic_id = t.id and post_number = 1) as like_count
from topics t
         left join app_user_external_info auei on t.user_id = auei.user_id
         join (select topic_id, max(created_at) as date from posts where user_id = #{user_id} and deleted_by_id is null and post_number > 1 group by topic_id) tab
              on tab.topic_id = t.id
where
    t.category_id in (#{category_ids}) and
    t.deleted_by_id is null and
    t.archetype = 'regular' and
    t.visible = true and
    t.closed = false
order by tab.date desc
limit #{page_size}
offset #{(current_page - 1) * page_size};
"
    result = ActiveRecord::Base.connection.execute(sql)

    count_sql = "
select count(*) as count
from topics t
         left join app_user_external_info auei on t.user_id = auei.user_id
         join (select topic_id, max(created_at) as date from posts where user_id = #{user_id} and deleted_by_id is null and post_number > 1 group by topic_id) tab
              on tab.topic_id = t.id
where
    t.category_id in (#{category_ids}) and
    t.deleted_by_id is null and
    t.archetype = 'regular' and
    t.visible = true and
    t.closed = false"

    count = ActiveRecord::Base.connection.execute(count_sql)

    [result, count.first["count"]]
  end

  def self.collect_list(page_size, current_page, user_id, category_ids)
    category_ids = category_ids.join(",")

    query = "
from topics t
         left join app_user_external_info auei on t.user_id = auei.user_id
         join bookmarks b on t.id = b.bookmarkable_id and b.bookmarkable_type = 'Topic'
where t.deleted_by_id is null and t.archetype = 'regular' and t.visible = true and t.closed = false
  and t.category_id in (#{category_ids})
  and b.user_id = #{user_id}
order by b.created_at desc"

    sql = "select t.id #{query}
limit #{page_size}
offset #{(current_page - 1) * page_size};"
    result = ActiveRecord::Base.connection.execute(sql)

    count_sql = "select count(*) as count"
    count = ActiveRecord::Base.connection.execute(count_sql)

    [result, count.first["count"]]
  end
end

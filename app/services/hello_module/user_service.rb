module ::HelloModule
  class UserService
    extend PostHelper

    def self.cal_user_info_by_id(user_id)
      if user_id.blank?
        return OpenStruct.new(
          user_id: "",
          name: "",
          avatar_url: "",
          is_upgrade: 0,
          )
      end
      external_info = AppUserExternalInfo.find_by(user_id: user_id)
      if !external_info.nil?
        userinfo = OpenStruct.new(
          user_id: user_id,
          name: "#{external_info.name}#{external_info.surname}",
          avatar_url: external_info.avatar_url,
          is_upgrade: external_info.is_upgrade,
        )
      else
        user = User.select("users.username as username, uploads.url as avatar_url")
                   .joins("LEFT JOIN uploads ON uploads.id = users.uploaded_avatar_id")
                   .find(user_id)
        userinfo = OpenStruct.new(
          user_id: user_id,
          name: "#{user.username}",
          avatar_url: user.avatar_url,
          is_upgrade: 0,
        )
      end

      userinfo
    end

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
order by b.updated_at desc"

      sql = "select t.id #{query}
limit #{page_size}
offset #{(current_page - 1) * page_size};"
      result = ActiveRecord::Base.connection.execute(sql)

      count_sql = "select count(*) as count"
      count = ActiveRecord::Base.connection.execute(count_sql)

      [result, count.first["count"]]
    end
  end
end

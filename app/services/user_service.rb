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
end

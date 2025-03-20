module ::HelloModule
  class CategoryService
    extend MyHelper
    extend PostHelper

    def self.all
      res = Category
              .select("
            categories.id,
            categories.name,
            categories.description,
            uploads.url as url,
            uploads.width as width,
            uploads.height as height")
              .joins("LEFT JOIN uploads ON categories.uploaded_logo_id = uploads.id")
              .where(read_restricted: false)
              .where("topic_id IS NOT NULL") # 系统默认的分类不显示
              .where("parent_category_id IS NULL") # 子分类不显示
              .all

      res = res.map do |category|
        {
          id: category["id"], # 分类id
          name: category["name"], # 分类名称
          url: format_url(category["url"]), # 分类头像
          width: category["width"], # 头像宽度
          height: category["height"], # 头像高度
          description: remove_html_tags(category["description"])
        }
      end

      res
    end

    def self.cal_interact_count(category_id)
      sql = "select category_id, count(1) as topic_count,(sum(posts_count) - count(1)) as comment_count, sum(like_count) as like_count
  from topics
  where category_id = #{category_id} and visible = true and deleted_by_id is null group by category_id;"

      raw = ActiveRecord::Base.connection.execute(sql)
      if raw.ntuples.zero? # 代表分类没有任何文章
        return 0
      end
      count = raw[0]["topic_count"].to_i + raw[0]["comment_count"].to_i + raw[0]["like_count"].to_i

      bookmarks_sql = "
  select count(1) from bookmarks where bookmarkable_type = 'Topic' and bookmarkable_id IN
  (select p.id from topics t join posts p on t.id = p.topic_id
  where t.category_id = #{category_id} and t.deleted_by_id is null and t.archetype = 'regular' and t.visible = true and t.closed = false
  and p.deleted_by_id is null and p.hidden = false);
  "
      bookmarks_raw = ActiveRecord::Base.connection.execute(bookmarks_sql)
      bookmarks_count = bookmarks_raw[0]["count"].to_i

      count += bookmarks_count

      count
    end

  end
end

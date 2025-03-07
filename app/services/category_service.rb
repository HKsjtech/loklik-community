class MyCustomError < StandardError; end

class CategoryService
  extend MyHelper

  def self.all(host)
    # 通过 openapi 获取分类列表
    openapi_client = OpenApiHelper.new(host)
    res = openapi_client.get("categories.json")

    # 提取 categories
    categories = res["category_list"]["categories"]
    # 过滤出 read_restricted 为 false 的分类 -- 管理员的不返回
    read_categories = categories.select { |category| category["read_restricted"] == false }
    # 处理成前端需要的数据格式
    category_map_ed = read_categories.map { |category| map_category(category) }

    category_map_ed
  end

  def self.show(host, category_id)
    # 通过 openapi 获取分类列表
    openapi_client = OpenApiHelper.new(host)
    res = openapi_client.get("c/#{category_id}/show.json")
    raise StandardError, res["error_type"] if res["errors"]

    # 提取 categories
    category = res["category"]
    # 过滤出 read_restricted 为 false 的分类 -- 管理员的不返回
    if category["read_restricted"]
      return nil
    end

    map_category(category)
  end

  def self.map_category(category)
    logo = category["uploaded_logo"]
    logo_url = ""
    logo_width = 0
    logo_height = 0

    if logo
      logo_url = "http:"+logo["url"]
      logo_width = logo["width"]
      logo_height = logo["height"]
    end

    {
      id: category["id"], # 分类id
      name: category["name"], # 分类名称
      url: logo_url, # 分类头像
      width: logo_width, # 头像宽度
      height: logo_height, # 头像高度
      description: category["description"]
    }
  end

  def self.cal_interact_count(category_id)
    sql = "select category_id, count(1) as topic_count,(sum(posts_count) - count(1)) as comment_count, sum(like_count) as like_count
from topics
where category_id = #{category_id} and deleted_by_id is null group by category_id;"

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

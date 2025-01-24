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
end

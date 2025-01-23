# frozen_string_literal: true

module ::HelloModule
  class CategoryController < ::ApplicationController
    include MyHelper
    requires_plugin PLUGIN_NAME
    skip_before_action :verify_authenticity_token # 跳过认证

    def region_list
      # todo: need to implement
      render_response(data: { region_list: 'region_list' })
    end

    def all
      # 通过 openapi 获取分类列表
      openapi_client = OpenApiHelper.new(get_request_host)
      res = openapi_client.get("categories.json")

      # 提取 categories
      categories = res["category_list"]["categories"]
      # 过滤出 read_restricted 为 false 的分类 -- 管理员的不返回
      read_categories = categories.select { |category| category["read_restricted"] == false }
      # 处理成前端需要的数据格式
      category_map_ed = read_categories.map { |category| map_category(category) }

      render_response(data: category_map_ed)
    end

    def map_category(category)
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
        height: logo_height # 头像高度
      }
    end

    def list
      # todo: need to implement
      render_response(data: 'list')
    end

    def show
      # todo: need to implement
      render_response(data: 'show')
    end


  end
end

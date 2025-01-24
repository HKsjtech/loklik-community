# frozen_string_literal: true

module ::HelloModule
  class CategoryController < ::ApplicationController
    include MyHelper
    requires_plugin PLUGIN_NAME
    skip_before_action :verify_authenticity_token # 跳过认证

    def region_list
      categories_selected = AppCategoriesSelected.order(sort: :asc).all
      categories_selected_ids = categories_selected.map { |c| c.categories_id }

      cate_srv = CategoryService.all(get_request_host)
      cas = cate_srv.filter { |category| categories_selected_ids.include?(category[:id]) }

      render_response(data: cas)
    end

    def all
      # 通过 openapi 获取分类列表
      res = CategoryService.all(get_request_host)
      render_response(data: res)
    end

    def list
      # todo: need to implement
      user_id = 1
      user_categories_list = AppUserCategories.where(is_deleted: 0, user_id: user_id)
      user_categories_ids = user_categories_list.map { |uc| uc.categories_id }

      cate_srv = CategoryService.all(get_request_host)

      mine = cate_srv.filter { |category| user_categories_ids.include?(category[:id]) }
      all = cate_srv.filter { |category| !user_categories_ids.include?(category[:id]) }

      render_response(data: {
        mime: mine,
        all: all
      })
    end

    def show
      category_id = params[:category_id]
      category = CategoryService.show(get_request_host, category_id)
      render_response(data: category)
    rescue StandardError => e
      render_response(success: false, code: 400, msg: "category not found")
    end

  end
end

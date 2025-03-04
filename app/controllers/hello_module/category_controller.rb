# frozen_string_literal: true

module ::HelloModule
  class CategoryController < ::ApplicationController
    include MyHelper
    include AuthHelper
    include PostHelper
    requires_plugin PLUGIN_NAME
    skip_before_action :verify_authenticity_token # 跳过认证
    before_action :fetch_current_user

    def region_list
      categories_selected = AppCategoriesSelected.order(sort: :asc).all
      categories_selected_ids = categories_selected.map { |c| c.categories_id }

      cate_srv = CategoryService.all(get_request_host)
      cas = categories_selected_ids.map do |category_id|
        cate_srv.find {|ca| ca[:id] == category_id}
      end

      render_response(data: cas)
    end

    def all
      # 通过 openapi 获取分类列表
      res = CategoryService.all(get_request_host)
      render_response(data: res)
    end

    def list
      user_id = get_current_user_id
      user_categories_list = AppUserCategories.where(is_deleted: 0, user_id: user_id).order(updated_at: :desc).all
      user_categories_ids = user_categories_list.pluck(:categories_id)

      cate_srv = CategoryService.all(get_request_host)

      # 这里需要 user_categories_ids 的排序，所以使用 user_categories_ids 去查找分类
      mine = user_categories_ids.map { |id| cate_srv.find {|ca| ca[:id] == id} }
      all = cate_srv # 产品修改了需求， 不需要排除已添加的分类了
              # .filter { |category| !user_categories_ids.include?(category[:id]) } # 去掉已添加的分类
      all.sort! { |a, b| b[:id] <=> a[:id] }

      render_response(data: {
        mine: mine,
        all: all
      })
    end

    def show
      category_id = (params.require(:category_id)).to_i
      if all_category_ids.exclude?(category_id)
        return render_response(success: false, code: 400, msg: "category not found")
      end

      category = Category.find(category_id)

      render_response(data: serialize_category(category))
    end

    private

    def serialize_category(category)
      add_category_count = AppUserCategories.where(categories_id: category.id, is_deleted: 0).count
      is_add_category = AppUserCategories.find_by(categories_id: category.id, user_id: @current_user.id, is_deleted: 0).present?
      urs = UploadReference
        .select("uploads.url as url")
        .joins("INNER JOIN uploads ON uploads.id = upload_references.upload_id")
        .where(target_type: "Category", target_id: category.id)
        .first
      {
        "id": category.id,
        "name": category.name,
        "url": format_url(urs&.url),
        "description": category.description,
        "isAddCategory": is_add_category,
        "addCategoryCount": add_category_count,
        "topicCount": category.topic_count,
        "interactCount": CategoryService.cal_interact_count(category.id),
      }
    end

    def fetch_current_user
      user_id = get_current_user_id
      @current_user = User.find_by_id(user_id)
    end
  end
end

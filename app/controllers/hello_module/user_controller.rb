# frozen_string_literal: true

module ::HelloModule
  class UserController < ::ApplicationController
    include MyHelper
    requires_plugin PLUGIN_NAME

    def join_category
      categories_id = params[:categoriesId]
      # 校验id是否存在
      unless Category.exists?(id: categories_id)
        return render_response(code: 400, success: false, msg: "论坛不存在")
      end

      # todo: 获取登陆的用户id
      user_id = 1

      unless AppUserCategories.upsert({ user_id: user_id, categories_id: categories_id, is_deleted: 0 }, unique_by: [:user_id, :categories_id])
        return render_response(code: 400, success: false, msg: "加入失败")
      end

      render_response
    end

    def leave_category
      categories_id = params[:categoriesId]

      # 校验id是否存在
      unless Category.exists?(id: categories_id)
        return render_response(code: 400, success: false, msg: "论坛不存在")
      end

      # todo: 获取登陆的用户id
      user_id = 1

      user_categories = AppUserCategories.find_by(user_id: user_id, categories_id: categories_id)
      unless  user_categories
        return render_response(code: 400, success: false, msg: "未加入论坛")
      end

      user_categories.is_deleted = 1
      unless user_categories.save
        return render_response(code: 500, success: false, msg: "退出失败")
      end

      render_response
    end

  end
end

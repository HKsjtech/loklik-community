# frozen_string_literal: true

module ::HelloModule
  class UserController < ::ApplicationController
    include MyHelper
    requires_plugin PLUGIN_NAME

    def join_category
      user_id = request.env['current_user_id']

      categories_id = params[:categoriesId]
      # 校验id是否存在
      unless Category.exists?(id: categories_id)
        return render_response(code: 400, success: false, msg: "论坛不存在")
      end

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

    def follow
      user_id = request.env['current_user_id']
      follow_external_user_id = params[:userId]

      ex_user = AppUserExternalInfo.find_by_external_user_id(follow_external_user_id)
      unless ex_user
        return render_response(code: 400, success: false, msg: "用户不存在")
      end

      if user_id == ex_user.user_id
        return render_response(code: 400, success: false, msg: "不能关注自己")
      end

      # 校验id是否存在
      unless AppUserFollow.upsert({ user_id: user_id, target_user_id: ex_user.user_id, is_deleted: 0 }, unique_by: [:user_id, :target_user_id])
        return render_response(code: 400, success: false, msg: "论坛不存在")
      end

      render_response
    end

    def cancel_follow
      user_id = request.env['current_user_id']

      follow_external_user_id = params[:userId]

      ex_user = AppUserExternalInfo.find_by_external_user_id(follow_external_user_id)
      unless ex_user
        return render_response(code: 400, success: false, msg: "用户不存在")
      end

      # 校验id是否存在
      user_follow = AppUserFollow.find_by(user_id: user_id, target_user_id: ex_user.user_id)
      unless user_follow
        return render_response(code: 400, success: false, msg: "未关注用户")
      end

      user_follow.is_deleted = 1
      unless user_follow.save
        return render_response(code: 500, success: false, msg: "取消关注失败")
      end

      render_response
    end

    def fans_list
      user_id = request.env['current_user_id']

      # 校验id是否存在
      user = User.find_by(id: user_id)
      unless user
        return render_response(code: 400, success: false, msg: "用户不存在")
      end

      fans_users = AppUserFollow.where(target_user_id: user_id, is_deleted: 0)
      fans_user_ids = fans_users.pluck(:user_id)

      follow_users = AppUserFollow.where(user_id: user_id, is_deleted: 0)
      follow_user_ids = follow_users.pluck(:target_user_id)

      fans_external_infos = AppUserExternalInfo.where(user_id: fans_user_ids, is_deleted: 0)

      res = fans_users.map do |fans_user|
        user_external_info = fans_external_infos.find_by(user_id: fans_user.user_id)
        unless user_external_info # 用户信息不存在
          next
        end
        serialize(fans_user, user_external_info, follow_user_ids)
      end


      render_response(data: res)
    end

    def care_list
      user_id = request.env['current_user_id']

      # 校验id是否存在
      user = User.find_by(id: user_id)
      unless user
        return render_response(code: 400, success: false, msg: "用户不存在")
      end

      care_users = AppUserFollow.where(user_id: user_id, is_deleted: 0)
      care_user_ids = care_users.pluck(:target_user_id)

      fans_users = AppUserFollow.where(target_user_id: user_id, is_deleted: 0)
      fans_user_ids = fans_users.pluck(:user_id)

      app_user_external_infos = AppUserExternalInfo.where(user_id: care_user_ids, is_deleted: 0)

      res = care_users.to_a.map do |care_user|
        user_external = app_user_external_infos.find_by(user_id: care_user.target_user_id)
        unless user_external
          next
        end
        serialize(care_user, user_external, fans_user_ids)
      end

      render_response(data: res)
    end

    def serialize(user_follow, user_external, fans_ids)
      {
        "id": user_external.user_id, #用户id
        "userId": user_external.external_user_id, #用户id
        "name": user_external.name, #用户名称
        "avatarUrl": user_external.avatar_url, #用户头像
        "careDateTime": user_follow.updated_at, #关注时间
        "isFans": fans_ids.include?(user_external.user_id) #是否粉丝
      }
    end

  end
end

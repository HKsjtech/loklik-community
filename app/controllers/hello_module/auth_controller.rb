# frozen_string_literal: true

module ::HelloModule
  class AuthController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    include MyHelper
    include AuthHelper

    def is_sync
      token = request.get_header("HTTP_AUTHORIZATION")
      if token.nil? || token.empty?
        return render_response(code: 401, success: false, msg: "token is required")
      end
      # 去掉 "Bearer " 前缀 得到 JWT
      token = token.sub("Bearer ", "") if token.start_with?("Bearer ")

      ok, user_external_id = get_user_external_id_by_token(token)
      unless ok && user_external_id
        render_response(code: 401, success: false, msg: "用户认证失败")
        return
      end

      external_info = AppUserExternalInfo.find_by_external_user_id(user_external_id)
      if external_info.nil?
        return render_response(data: { is_sync: false })
      end

      render_response(data: { is_sync: !external_info.nil? })
    end

  end
end

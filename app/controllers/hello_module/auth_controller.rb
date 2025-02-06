# frozen_string_literal: true

module ::HelloModule
  class AuthController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    include MyHelper
    include AuthHelper

    def is_sync
      token = request.get_header("HTTP_AUTHORIZATION")
      # 去掉 "Bearer " 前缀 得到 JWT
      token = token.sub("Bearer ", "")

      ok, user_external_id = get_user_external_id_by_token(token)
      unless ok
        render_response(code: 401, success: false, msg: "用户认证失败")
        return
      end

      external_info = AppUserExternalInfo.find_by_external_user_id(user_external_id)

      render_response(data: { is_sync: !external_info.nil? })
    end

  end
end

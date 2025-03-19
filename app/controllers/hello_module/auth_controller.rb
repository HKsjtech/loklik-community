# frozen_string_literal: true

module ::HelloModule
  class AuthController < CommonController
    requires_plugin PLUGIN_NAME
    include MyHelper
    include AuthHelper

    def is_sync
      token = request.get_header("HTTP_SJTOKEN")
      if token.nil? || token.empty?
        return render_response(code: 401, success: false, msg: I18n.t("loklik.params_error", params: "token"))
      end
      # 去掉 "Bearer " 前缀 得到 JWT
      token = token.sub("Bearer ", "") if token.start_with?("Bearer ")

      redis_key = "loklik_plugin:jwt_token:#{token}"

      user_id = Redis.current.get(redis_key)
      if user_id
        # JWT 有效，直接返回 true
        return render_response(data: { isSync: true })
      end

      ok, user_external_id = get_user_external_id_by_token(token)
      unless ok && user_external_id
        return render_response(data: { isSync: false })
      end

      external_info = AppUserExternalInfo.find_by_external_user_id(user_external_id)

      render_response(data: { isSync: !external_info.nil? })
    end

  end
end

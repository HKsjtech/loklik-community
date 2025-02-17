# lib/discourse_jwt_middleware/middleware.rb

require_relative '../../app/helpers/auth_helper'
require_relative '../../app/helpers/my_helper'
module ::HelloModule
  class Middleware
    include AuthHelper
    include MyHelper
    def initialize(app)
      @app = app
      @exclude_routes = [
        "/loklik/user",
        "/loklik/base",
        "/loklik/category",
        "/loklik/post",
        "/loklik/topic",
      ]
    end

    def call(env)
      request = Rack::Request.new(env)

      # 排除受保护的路由
      unless @exclude_routes.any? { |route| request.path.start_with?(route) }
        puts "request path: #{request.path}"
        @app.call(env)
        return
      end
      puts "============="
      begin
        # 获取 HTTP_SJTOKEN
        token = request.get_header("HTTP_SJTOKEN")

        if SiteSetting.app_auth_host.blank?
          # JWT 无效，返回 401
          return [200, { "Content-Type" => "application/json" },
                  [response_format(code: 401, success: false, msg: "app_auth_host not set on server").to_json]
          ]
        end

        # 校验 JWT
        ok, user_id = valid_jwt?(token)
        unless ok
          # JWT 无效，返回 401
          return [200, { "Content-Type" => "application/json" },
                  [response_format(code: 401, success: false, msg: "Unauthorized1").to_json]
          ]
        end

        # 设置当前用户 ID
        env['current_user_id'] = user_id
        @app.call(env)
      rescue StandardError => e
        LoggerHelper.error(e)
        [200, { "Content-Type" => "application/json" }, [response_format(code: 500, success: false, msg: 'Internal Server Error', error: e.message).to_json]]
      end
    end

    private

    def valid_jwt?(token)
      # 在这里实现您的 JWT 校验逻辑
      unless token
        LoggerHelper.error("invalid token: #{token}")
        return false, nil
      end

      # 去掉 "Bearer " 前缀 得到 JWT
      token = token.sub("Bearer ", "") if token.start_with?("Bearer ")

      redis_key = "jwt_token:#{token}"

      user_id = Redis.current.get(redis_key)
      if user_id
        # JWT 有效，直接返回 true
        return true, user_id
      end

      ok, user_external_id = get_user_external_id_by_token(token)
      unless ok
        LoggerHelper.error("get_user_external_id_by_token failed.")
        return false, nil
      end

      external_info = AppUserExternalInfo.find_by_external_user_id(user_external_id)
      unless external_info
        LoggerHelper.error("get_user_external_id_by_token failed: #{user_external_id}")
        return false, nil
      end

      # JWT 有效，存入 Redis，3600 秒过期 1h
      Redis.current.set(redis_key, external_info.user_id, ex: 8*3600)
      LoggerHelper.info("redis set #{redis_key} #{external_info.user_id}")

      [true, external_info.user_id]
    end


  end
end

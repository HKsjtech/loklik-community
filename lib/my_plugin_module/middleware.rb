# lib/discourse_jwt_middleware/middleware.rb

# howto require_relative 'my_helper'
require_relative '../../app/helpers/my_helper'

module ::HelloModule
  class Middleware
    include MyHelper
    def initialize(app)
      @app = app
      @exclude_routes = [
        "/loklik/user",
        "/loklik/base",
        "/loklik/category",
      ]
    end

    def call(env)
      request = Rack::Request.new(env)

      # 排除受保护的路由
      unless @exclude_routes.any? { |route| request.path.start_with?(route) }
        return @app.call(env)
      end

      # 从请求头中获取 JWT
      token = request.get_header("HTTP_AUTHORIZATION")

      # 校验 JWT
      if valid_jwt?(token)
        @app.call(env)  # JWT 合法，继续处理请求
      else
        [401, { "Content-Type" => "application/json" },
         [response_format(code: 401, success: false, msg: "Unauthorized").to_json]
        ]
      end

    end

    private

    def valid_jwt?(token)
      # 在这里实现您的 JWT 校验逻辑
      return false unless token && token.start_with?("Bearer ")

      # JWT 有效，存入 Redis，3600 秒过期
      Redis.current.set("jwt_token:#{token}", "11111", ex: 3600)
      puts Redis.current.get("jwt_token:#{token}")

      puts "===", generate_sso_redirect_url(token)

      # 请求 token 接口
      # {
      #     "code": 200,//响应code
      #     "msg": "ok",//提示消息
      #     "data": "156131455541"//用户Id **注：若该字段返回为空，则token无效**
      # }

      # 将结果写入 Redis，3600 秒过期 key为token，value为 discourse 本地字符串
      # Redis.current.set("jwt_token_result:#{token}", result.to_json, ex: 3600)
      # puts Redis.current.get("jwt_token_result:#{token}")

      true
    end

    def generate_sso_redirect_url(token)
      secret = SiteSetting.discourse_connect_secret

      # 1. 生成 nonce
      nonce = SecureRandom.random_number(10**10).to_s

      # 2. 生成 payload
      payload = "nonce=#{nonce}&token=#{token}"

      # 3. payload base64 编码
      base64_payload = Base64.urlsafe_encode64(payload)

      # 4. payload URL 编码（可选，因为 base64_urlsafe_encode64 已经处理）
      encoded_payload = URI.encode_www_form_component(base64_payload)

      # 5. 对 base64 编码进行 HMAC-SHA256
      sig = OpenSSL::HMAC.hexdigest('SHA256', secret, base64_payload)

      # 6. 构造重定向地址
      redirect_uri = "sso=#{encoded_payload}&sig=#{sig}"

      redirect_uri
    end
  end
end

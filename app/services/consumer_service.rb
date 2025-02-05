require 'base64'
require 'uri'
require 'openssl'

class ConsumerService
  extend MyHelper

  def self.consumer_user_login(body)
    return nil unless SiteSetting.enable_discourse_connect
    return nil unless SiteSetting.discourse_connect_secret
    user_info = JSON.parse(body)

    user = request_sso(user_info)

    puts "====sso res:", user
    app_user_external_info = HelloModule::AppUserExternalInfo.find_or_initialize_by(
      user_id: user["id"],
      external_user_id: user_info["userId"]
    )

    # 更新或设置其他字段
    app_user_external_info.name = user_info["name"]
    app_user_external_info.surname = user_info["surname"]
    app_user_external_info.avatar_url = user_info["avatarUrl"]
    app_user_external_info.is_deleted = 0
    app_user_external_info.is_upgrade = user_info["isUpgrade"]

    app_user_external_info.save

    user
  end

  def self.request_sso(user_info)
    sso_params = {
      'external_id' => user_info["userId"],
      'email' => user_info["email"],
      'username' => user_info["username"],
      'name' => user_info["name"],
    }

    # 将 SSO 参数转换为 SSO 负载并生成 SSO 签名
    sso_payload = Base64.strict_encode64(URI.encode_www_form(sso_params))
    sig = OpenSSL::HMAC.hexdigest('SHA256',  SiteSetting.discourse_connect_secret, sso_payload)

    post_fields = {
      'sso' => sso_payload,
      'sig' => sig
    }

    headers = { # todo: api-key
      'Api-Key' => "32a4add3ddd1963fa682be0c0b30ee9c3de28acf6da11a456809758887f342cd",
      'Api-Username' => "discobot"
    }

    # 通过 openapi 获取分类列表
    openapi_client = OpenApiHelper.new(Discourse.base_url)
    openapi_client.form("admin/users/sync_sso", post_fields, headers)
  end
end


require 'base64'
require 'uri'
require 'openssl'

class ConsumerService
  extend MyHelper

  def self.consumer_user_login(body)
    unless SiteSetting.enable_discourse_connect
      LoggerHelper.warn("Discourse Connect is not enabled")
      return nil
    end
    unless SiteSetting.discourse_connect_secret
      LoggerHelper.warn("Discourse Connect Secret is not set")
      return nil
    end
    unless SiteSetting.plugin_discourse_api_secret
      LoggerHelper.warn("Discourse API Secret is not set")
      return nil
    end
    LoggerHelper.info("begin handle consumer")

    user_info = JSON.parse(body)

    user = request_sso(user_info)
    if user.nil?
      LoggerHelper.error("Failed to get user from Discourse")
      return nil
    end

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

    unless app_user_external_info.save
      LoggerHelper.error("Failed to save app user")
    end

    user
  rescue => e
    LoggerHelper.error("Failed to login user from Discourse: #{e.message}")
    nil
  end

  # {"avatarUrl":"https://sjtech-public.s3.amazonaws.com/avatar/constellation/sagittarius.png","isUpgrade":1,"name":"翔","surname":"贺","userId":"1879721790746529792"}
  def self.consumer_user_update(body)
    unless SiteSetting.enable_discourse_connect
      LoggerHelper.warn("Discourse Connect is not enabled")
      return nil
    end
    unless SiteSetting.discourse_connect_secret
      LoggerHelper.warn("Discourse Connect Secret is not set")
      return nil
    end
    unless SiteSetting.plugin_discourse_api_secret
      LoggerHelper.warn("Discourse API Secret is not set")
      return nil
    end

    user_info = JSON.parse(body)

    app_user_external_info = HelloModule::AppUserExternalInfo.find_by(
      external_user_id: user_info["userId"]
    )

    if app_user_external_info.nil?
      LoggerHelper.error("Failed to find app user")
      return nil
    end

    # 更新或设置其他字段
    app_user_external_info.name = user_info["name"]
    app_user_external_info.surname = user_info["surname"]
    app_user_external_info.avatar_url = user_info["avatarUrl"]
    app_user_external_info.is_upgrade = user_info["isUpgrade"]

    LoggerHelper.info("new user info: #{app_user_external_info.inspect}")

    unless app_user_external_info.save
      LoggerHelper.error("Failed to save app user")
    end

    user
  rescue => e
    LoggerHelper.error("Failed to login user from Discourse: #{e.message}")
    nil
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

    headers = {
      'Api-Key' => SiteSetting.plugin_discourse_api_secret,
      'Api-Username' => "system"
    }

    openapi_client = OpenApiHelper.new(Discourse.base_url)
    openapi_client.form("admin/users/sync_sso", post_fields, headers)
  end
end


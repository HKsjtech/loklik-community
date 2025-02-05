module AuthHelper
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
    "sso=#{encoded_payload}&sig=#{sig}"
  end

  def get_user_external_id_by_token(token)
    params = generate_sso_redirect_url(token)
    # 发起请求，获取用户信息
    url = "http://172.16.116.218:7777/sso/checkToken?#{params}"

    openapi_client = OpenApiHelper.new(Discourse.base_url)
    result = openapi_client.get(url)
    puts result
    unless result["code"] == 200 && result["data"]
      return false, nil
    end

    [true, result["data"]]
  end
end

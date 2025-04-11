# frozen_string_literal: true

module ::HelloModule
  class InnerTopicController < CommonController
    include MyHelper
    include PostHelper
    include DiscourseHelper
    include AuthHelper
    requires_plugin PLUGIN_NAME
    skip_before_action :verify_authenticity_token # 跳过认证
    before_action :decrypt_params

    def create_topic_async
      LoggerHelper.info "解密后的参数 @params: #{@params}"
      external_user_id = @params["userId"]
      if external_user_id.blank?
        return render_response(success: false, msg: "userId is blank")
      end
      user_external_info = AppUserExternalInfo.find_by(external_user_id: external_user_id)
      if user_external_info.blank?
        LoggerHelper.error "user_external_info is blank. userExternalId: #{external_user_id}"
        return render_response(success: false, msg: "user_external_info is blank")
      end

      args = {
        user_id: user_external_info.user_id,
        title: @params["title"],
        raw: @params["raw"],
        category_id: SiteSetting.work_topic_category_id,
        images: @params["imageUrls"],
        ext: {
          work_id: @params["workId"],
        }
      }
      # 触发异步任务
      Jobs.enqueue(
        :post_topic_worker,
        args,
        )
      render_response(success: true, msg: "success")
    end


    private
    def decrypt_params
      # 解密参数
      data = params[:data]
      aes_key = SiteSetting.aes_decrypt_secret_key
      if aes_key.blank?
        raise "aes_decrypt_secret_key is blank"
      end
      decrypt_data = AesHelper.aes_decrypt(data, aes_key)
      @params = JSON.parse(decrypt_data)
    rescue OpenSSL::Cipher::CipherError => e
      render json: response_format(code: 401, success: false, msg: 'Unauthenticated', error: e.message)
      return false # 终止后续动作
    rescue JSON::ParserError
      render json: response_format(code: 500, success: false, msg: 'Format error', error: e.message)
      return false # 终止后续动作
    rescue => e
      render json: response_format(code: 500, success: false, msg: 'Internal server error', error: e.message)
      return false # 终止后续动作
    end

  end
end


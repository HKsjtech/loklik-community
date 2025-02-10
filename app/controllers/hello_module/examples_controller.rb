# frozen_string_literal: true

module ::HelloModule
  class ExamplesController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    include MyHelper

    def index
      LoggerHelper.info("这是一个信息日志")
      LoggerHelper.warn("这是一个警告日志")
      LoggerHelper.error("这是一个错误日志")
      render_response(data: "Hello, world!")
    end

    def test_sync_user
      msg = '{
    "avatarUrl": "http://s3.amazonaws.com/loklik-idea-studio-public-dev/avatar/1831162626387005440.png",
    "email": "335072884@qq.com",
    "isUpgrade": 1,
    "name": "wu4",
    "surname": "qf4",
    "userId": "1817839402091683844",
    "username": "u_qf4"
}'
      res = ConsumerService.consumer_user_login(msg)
      render_response(data: res)
    end

  end
end

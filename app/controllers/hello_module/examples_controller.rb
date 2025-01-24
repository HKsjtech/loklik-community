# frozen_string_literal: true

module ::HelloModule
  class ExamplesController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    include MyHelper

    def index
      msg = '{
    "avatarUrl": "http://s3.amazonaws.com/loklik-idea-studio-public-dev/avatar/1831162626387005440.png",
    "email": "335072883@qq.com",
    "isUpgrade": 1,
    "name": "wu3",
    "surname": "qf3",
    "userId": "1817839402091683843",
    "username": "u_qf3"
}'
      res = ConsumerService.consumer_user_login(msg)
      render_response(data: res)
    end

  end
end

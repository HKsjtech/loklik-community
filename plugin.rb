# frozen_string_literal: true

# name: loklik-community
# about: loklik community plugin
# meta_topic_id: TODO
# version: 0.0.2
# authors: Sijiu tech
# url: TODO
# required_version: 2.7.0

gem "rbtree3", '0.7.1', { require: false }
gem "set", '1.0.3', { require: false }
gem "sorted_set", '1.0.2', { require: false }
gem "amq-protocol", '2.3.2', { require: false }
gem "bunny" , '2.23.0', { require: false }

module ::HelloModule
  PLUGIN_NAME = "loklik-community"
end

require_relative "lib/my_plugin_module/engine"

after_initialize do
end

#  增加管理页面
add_admin_route 'purple_tentacle.title', 'purple-tentacle'

Discourse::Application.routes.append do
  get '/admin/plugins/purple-tentacle' => 'admin/plugins#index', constraints: StaffConstraint.new
end

register_asset "stylesheets/my-plugin.css"


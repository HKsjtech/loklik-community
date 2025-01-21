# frozen_string_literal: true

# name: loklik-community
# about: loklik community plugin
# meta_topic_id: TODO
# version: 0.0.1
# authors: Sijiu tech
# url: TODO
# required_version: 2.7.0

enabled_site_setting :plugin_name_enabled

module ::HelloModule
  PLUGIN_NAME = "loklik-community"
end

require_relative "lib/my_plugin_module/engine"

after_initialize do
  # Code which should run after Rails has finished booting
end


#  增加管理页面
add_admin_route 'purple_tentacle.title', 'purple-tentacle'

Discourse::Application.routes.append do
  get '/admin/plugins/purple-tentacle' => 'admin/plugins#index', constraints: StaffConstraint.new
end

register_asset "stylesheets/my-plugin.css"



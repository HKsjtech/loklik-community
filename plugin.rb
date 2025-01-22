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
  # print("===auto migrate cancel===\n")
  # # 自动迁移
  # require_dependency 'active_record'
  #
  # migration_context = ActiveRecord::MigrationContext.new(Rails.root.join("plugins/loklik-community/db/migrate"))
  # migration_context.migrate
  # print("===auto migrate success===\n")
end


#  增加管理页面
add_admin_route 'purple_tentacle.title', 'purple-tentacle'

Discourse::Application.routes.append do
  get '/admin/plugins/purple-tentacle' => 'admin/plugins#index', constraints: StaffConstraint.new
end

register_asset "stylesheets/my-plugin.css"



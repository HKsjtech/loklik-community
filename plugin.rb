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

# ar_SA.js.erb  es_CL.js.erb  it_IT.js.erb  nl_NL.js.erb
# de_CH.js.erb  es_MX.js.erb  ja_JP.js.erb  pt_PT.js.erb
# en_US.js.erb  fr_BE.js.erb  ko_KR.js.erb  ru_RU.js.erb
register_locale("ar_SA", name: "Arabic (Saudi Arabia)", nativeName: "العربية (المملكة العربية السعودية)", fallbackLocale: "ar")
register_locale("es_CL", name: "Spanish (Chile)", nativeName: "Español (Chile)", fallbackLocale: "es")
register_locale("it_IT", name: "Italian (Italy)", nativeName: "Italiano (Italia)", fallbackLocale: "it")
register_locale("nl_NL", name: "Dutch (Netherlands)", nativeName: "Nederlands (Nederland)", fallbackLocale: "nl")
register_locale("de_CH", name: "German (Switzerland)", nativeName: "Deutsch (Schweiz)", fallbackLocale: "de")
register_locale("es_MX", name: "Spanish (Mexico)", nativeName: "Español (México)", fallbackLocale: "es")
register_locale("ja_JP", name: "Japanese (Japan)", nativeName: "日本語 (日本)", fallbackLocale: "ja")
register_locale("pt_PT", name: "Portuguese (Portugal)", nativeName: "Português (Portugal)", fallbackLocale: "pt")
register_locale("en_US", name: "English (United States)", nativeName: "English (United States)", fallbackLocale: "es")
register_locale("fr_BE", name: "French (Belgium)", nativeName: "Français (Belgique)", fallbackLocale: "fr")
register_locale("ko_KR", name: "Korean (South Korea)", nativeName: "한국어 (대한민국)", fallbackLocale: "ko")
register_locale("ru_RU", name: "Russian (Russia)", nativeName: "Русский (Россия)", fallbackLocale: "ru")

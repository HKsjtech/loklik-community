# frozen_string_literal: true

HelloModule::Engine.routes.draw do
  get "/hello" => "examples#index"
  get "/examples/test_amqp" => "examples#test_amqp"
  post "/examples/test_post" => "examples#test_post"

  # base routes
  get "/base/banner-list" => "base#banner_list"
  get "/base/search" => "base#search"
  post "/base/upload" => "base#upload"
  get "/base/discourse-host" => "base#discourse_host"

  # auth routes
  get "/auth/is-sync" => "auth#is_sync"

  # category routes
  get "/category/region-list" => "category#region_list"
  get "/category/all" => "category#all"
  get "/category/list" => "category#list"
  get "/category/:category_id" => "category#show"

  # post routes
  get "/post/curated-list" => "post#curated_list"
  get "/post/latest-list" => "post#latest_list"
  get "/post/list/:category_id" => "post#list_show"
  get "/post/:topic_id" => "post#show"

  get "/post/:topic_id/comment-list/:post_number" => "post#comment_list"
  post "/post/:topic_id/collect" => "post#topic_collect"
  put "/post/:topic_id/cancel-collect" => "post#topic_collect_cancel"
  post "/post/:post_id/like" => "post#post_like"
  put "/post/:post_id/cancel-like" => "post#post_like_cancel"


  get "/topic/:topic_id/comment-list" => "topic#comment_list"
  get "/topic/:topic_id/comment-list/:post_number" => "topic#post_show"

  # user routers
  post "/user/category" => "user#join_category"
  put "/user/category/:categoriesId" => "user#leave_category"
  post "/user/follow" => "user#follow"
  put "/user/follow/:userId" => "user#cancel_follow"
  get "/user/fans-list" => "user#fans_list"
  get "/user/care-list" => "user#care_list"
  post "/user/post" => "user#create_topic"
  put "/user/post" => "user#edit_topic"
  delete "/user/post/:topic_id" => "user#destroy_topic"
  post "/user/comment" => "user#comment"
  delete "/user/post/comment/:post_id" => "user#destroy_post"
  post "/user/report" => "user#report"
  get "/user/detail" => "user#detail"
  get "/user/like-list" => "user#like_list"
  get "/user/post-list" => "user#user_topic_list"
  get "/user/comment-list" => "user#comment_list"

  # admin routes
  get "/admin/index" => "admin#index"
  put "/admin/curated/:topic_id" => "admin#curated"
  get "/admin/categories" => "admin#categories"
  get "/admin/select_categories" => "admin#select_categories"
  post "/admin/set_select_categories" => "admin#set_select_categories"


end

Discourse::Application.routes.draw { mount ::HelloModule::Engine, at: "loklik" }

# frozen_string_literal: true

module ::HelloModule
  class UserController < ::ApplicationController
    include MyHelper
    requires_plugin PLUGIN_NAME

    skip_before_action :verify_authenticity_token # 跳过认证
    before_action :fetch_current_user

    def join_category
      user_id = request.env['current_user_id']

      categories_id = params[:categoriesId]
      # 校验id是否存在
      unless Category.exists?(id: categories_id)
        return render_response(code: 400, success: false, msg: "论坛不存在")
      end

      unless AppUserCategories.upsert({ user_id: user_id, categories_id: categories_id, is_deleted: 0 }, unique_by: [:user_id, :categories_id])
        return render_response(code: 400, success: false, msg: "加入失败")
      end

      render_response
    end

    def leave_category
      categories_id = params[:categoriesId]

      # 校验id是否存在
      unless Category.exists?(id: categories_id)
        return render_response(code: 400, success: false, msg: "论坛不存在")
      end

      # todo: 获取登陆的用户id
      user_id = 1

      user_categories = AppUserCategories.find_by(user_id: user_id, categories_id: categories_id)
      unless  user_categories
        return render_response(code: 400, success: false, msg: "未加入论坛")
      end

      user_categories.is_deleted = 1
      unless user_categories.save
        return render_response(code: 500, success: false, msg: "退出失败")
      end

      render_response
    end

    def follow
      user_id = request.env['current_user_id']
      follow_external_user_id = params[:userId]

      ex_user = AppUserExternalInfo.find_by_external_user_id(follow_external_user_id)
      unless ex_user
        return render_response(code: 400, success: false, msg: "用户不存在")
      end

      if user_id == ex_user.user_id
        return render_response(code: 400, success: false, msg: "不能关注自己")
      end

      # 校验id是否存在
      unless AppUserFollow.upsert({ user_id: user_id, target_user_id: ex_user.user_id, is_deleted: 0 }, unique_by: [:user_id, :target_user_id])
        return render_response(code: 400, success: false, msg: "论坛不存在")
      end

      render_response
    end

    def cancel_follow
      user_id = request.env['current_user_id']

      follow_external_user_id = params[:userId]

      ex_user = AppUserExternalInfo.find_by_external_user_id(follow_external_user_id)
      unless ex_user
        return render_response(code: 400, success: false, msg: "用户不存在")
      end

      # 校验id是否存在
      user_follow = AppUserFollow.find_by(user_id: user_id, target_user_id: ex_user.user_id)
      unless user_follow
        return render_response(code: 400, success: false, msg: "未关注用户")
      end

      user_follow.is_deleted = 1
      unless user_follow.save
        return render_response(code: 500, success: false, msg: "取消关注失败")
      end

      render_response
    end

    def fans_list
      user_id = request.env['current_user_id']

      # 校验id是否存在
      user = User.find_by(id: user_id)
      unless user
        return render_response(code: 400, success: false, msg: "用户不存在")
      end

      fans_users = AppUserFollow.where(target_user_id: user_id, is_deleted: 0)
      fans_user_ids = fans_users.pluck(:user_id)

      follow_users = AppUserFollow.where(user_id: user_id, is_deleted: 0)
      follow_user_ids = follow_users.pluck(:target_user_id)

      fans_external_infos = AppUserExternalInfo.where(user_id: fans_user_ids, is_deleted: 0)

      res = fans_users.map do |fans_user|
        user_external_info = fans_external_infos.find_by(user_id: fans_user.user_id)
        unless user_external_info # 用户信息不存在
          next
        end
        serialize(fans_user, user_external_info, follow_user_ids)
      end


      render_response(data: res)
    end

    def care_list
      user_id = request.env['current_user_id']

      # 校验id是否存在
      user = User.find_by(id: user_id)
      unless user
        return render_response(code: 400, success: false, msg: "用户不存在")
      end

      care_users = AppUserFollow.where(user_id: user_id, is_deleted: 0)
      care_user_ids = care_users.pluck(:target_user_id)

      fans_users = AppUserFollow.where(target_user_id: user_id, is_deleted: 0)
      fans_user_ids = fans_users.pluck(:user_id)

      app_user_external_infos = AppUserExternalInfo.where(user_id: care_user_ids, is_deleted: 0)

      res = care_users.to_a.map do |care_user|
        user_external = app_user_external_infos.find_by(user_id: care_user.target_user_id)
        unless user_external
          next
        end
        serialize(care_user, user_external, fans_user_ids)
      end

      render_response(data: res)
    end

    # {
    #     "categoryId": 4,//分类id
    #     "title": "1243",//标题
    #     "raw": "最后的测试ger3",//内容
    #     "video": "http://s3.amazonaws.com/loklik-ide478d5a19.mp4",//视频链接
    #     "image": [{//图片
    #         "originalName": "1.jpg",//图片原名字
    #         "thumbnailWidth": 690,//缩略图宽度
    #         "thumbnailHeight": 388,//缩略图高度
    #         "shortUrl": "upload://uw9mpzIzNWsbV9j2Tad9AEWpZ8C.jpeg"//图片短链接
    #     },{
    #         "originalName": "code.jpg",
    #         "thumbnailWidth": 100,
    #         "thumbnailHeight": 40,
    #         "shortUrl": "upload://a8obYu9AYDfuiUWq5e9kBNR8V3g.png"
    #     }]
    # }
    def post
      min_topic_title_length = SiteSetting.min_topic_title_length || 8
      min_post_length = SiteSetting.min_post_length || 8



      puts "min_topic_title_length: #{min_topic_title_length}"
      puts "min_post_length: #{min_post_length}"
      title = params[:title]
      raw = params[:raw]

      if title.length < min_topic_title_length
        return render_response(code: 400, success: false, msg: "标题长度不能少于#{min_topic_title_length}个字符")
      end

      if raw.length < min_post_length
        return render_response(code: 400, success: false, msg: "内容长度不能少于#{min_post_length}个字符")
      end
      puts params[:image]

      raw += cal_new_post_raw(params[:image], params[:video]) if params[:image] || params[:video]

      manager_params = {}
      manager_params[:raw] = raw
      manager_params[:title] = params[:title]
      manager_params[:category] = params[:categoryId]
      manager_params[:first_post_checks] = false
      manager_params[:advance_draft] = false
      manager_params[:ip_address] = request.remote_ip
      manager_params[:user_agent] = request.user_agent

      begin
        manager = NewPostManager.new(@current_user, manager_params)
        res = serialize_data(manager.perform, NewPostResultSerializer, root: false)

        puts res
        if res && res[:errors] && res[:errors].any?
          render_response(code: 400, success: false, msg: res[:errors].join(", "))
        else
          render_response(data: res[:post][:topic_id], success: true, msg: "发帖成功")
        end
      rescue => e
        render_response(code: 400, success: false, msg: e.message)
      end
    end

    def edit_post
      changes = {}
      changes[:title] = params[:title] if params[:title]
      if params[:raw]
        changes[:raw] = params[:raw] + cal_new_post_raw(params[:image], params[:video]) if params[:image] || params[:video]
      end

      if changes.none?
        return render_response(code: 400, success: false, msg: "没有任何修改")
      end

      # post = Post.where(id: params[:id])
      # post = post.with_deleted if guardian.is_staff?
      # post = post.first
      topic = Topic.find_by(id: params[:topicId].to_i)

      unless topic
        return render_response(code: 400, success: false, msg: "帖子不存在")
      end

      puts "topic: #{topic.inspect}"
      first_post = topic.ordered_posts.first

      success =
        PostRevisor.new(first_post, topic).revise!(
          @current_user,
          changes,
          validate_post: false,
          bypass_bump: false,
          keep_existing_draft: false,
          )

      return render_response(code: 400, success: false, msg: topic.errors.full_messages.join(", ")) if !success && topic.errors.any?

      render_response
    end

    def serialize(user_follow, user_external, fans_ids)
      {
        "id": user_external.user_id, #用户id
        "userId": user_external.external_user_id, #用户id
        "name": user_external.name, #用户名称
        "avatarUrl": user_external.avatar_url, #用户头像
        "careDateTime": user_follow.updated_at, #关注时间
        "isFans": fans_ids.include?(user_external.user_id) #是否粉丝
      }
    end

    private

    def fetch_current_user
      user_id = request.env['current_user_id']
      @current_user = User.find_by_id(user_id)
    end

    def cal_new_post_raw(images, video)
      res = ""

      # 图片
      if images.present?
        images.each do |image|
          # ![image|690x316](upload://ttjM3OvnCo3NRd3mx8jSq4edWw1.png)
          res += "\n![image|#{image[:thumbnailWidth]}x#{image[:thumbnailHeight]}](#{image[:shortUrl]})"
        end
      end

      # 视频
      res += "\n\n#{video}" if video

      res
    end

  end
end

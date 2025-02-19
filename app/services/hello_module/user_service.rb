module ::HelloModule
  class UserService
    extend PostHelper

    def self.cal_user_info_by_id(user_id)
      external_info = AppUserExternalInfo.find_by(user_id: user_id)
      if !external_info.nil?
        userinfo = OpenStruct.new(
          user_id: user_id,
          name: "#{external_info.surname}#{external_info.name}",
          avatar_url: external_info.avatar_url
        )
      else
        user = User.select("users.username as username, uploads.url as avatar_url")
                   .joins("LEFT JOIN uploads ON uploads.id = users.uploaded_avatar_id")
                   .find(user_id)
        userinfo = OpenStruct.new(
          user_id: user_id,
          name: "#{user.username}",
          avatar_url: user.avatar_url,
        )
      end

      userinfo
    end

  end
end

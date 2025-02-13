class PostService
  def self.handle_post_action(current_user, post, action_name_key, is_topic, message = nil)
    post_action_type = PostActionType.find_by_name_key(action_name_key)
    unless post_action_type
      raise "Post action type not found"
    end
    creator = PostActionCreator.new(
      current_user,
      post,
      post_action_type.id,
    )
    puts "message: #{message}"
    PostActionCreator.new(
      current_user,
      post,
      7,
      message: message,
      flag_topic: `is_topic`,
      )

    creator.perform
  end
end

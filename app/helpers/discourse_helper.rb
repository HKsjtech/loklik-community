module DiscourseHelper
  def get_operator_msg(result)
    result.errors.full_messages.join(", ")
  end
end

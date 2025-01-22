# frozen_string_literal: true
module BaseModule
  class Response
    def aa

    end
  end

  def render_response(data: nil, code: 200, success: true, msg: "操作成功")
    render json: {
      code: code,
      success: success,
      data: data,
      msg: msg
    }, status: code
  end

  def create_page_list(data, total, current, size)
    {
      records: data,
      total: total,
      size: size,
      current: current
    }
  end
end

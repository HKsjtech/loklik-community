module MyHelper
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

  def get_request_host
    # 获取当前请求的完整 URL
    # request_url = "#{request.protocol}#{request.host_with_port}#{request.fullpath}"
    "#{request.protocol}#{request.host_with_port}"
  end
end

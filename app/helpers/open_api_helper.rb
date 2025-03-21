require 'net/http'
require 'uri'
require 'json'

class OpenApiHelper
  def initialize(base_url)
    @base_url = base_url
  end

  def get(endpoint, headers = {})
    url = URI.join(@base_url, endpoint)
    request = Net::HTTP::Get.new(url)
    headers.each { |key, value| request[key] = value }

    response = send_request(url, request)
    handle_response(response)
  end

  def post(endpoint, body, headers = {})
    url = URI.join(@base_url, endpoint)
    request = Net::HTTP::Post.new(url)
    headers.each { |key, value| request[key] = value }
    request.body = body.to_json

    response = send_request(url, request)
    handle_response(response)
  end

  def form(endpoint, post_fields, headers = {})
    uri = URI.join(@base_url, endpoint)
    request = Net::HTTP::Post.new(uri)
    headers.each { |key, value| request[key] = value }
    request['Content-Type'] = 'multipart/form-data'
    request.set_form_data(post_fields)

    response = send_request(uri, request)
    handle_response(response)
  end

  def form_file(endpoint, post_fields, headers = {}, file_path)
    uri = URI.join(@base_url, endpoint)
    request = Net::HTTP::Post.new(uri)
    headers.each { |key, value| request[key] = value }
    request['Content-Type'] = 'multipart/form-data'
    uploaded_file = Rack::Test::UploadedFile.new(file_path, 'application/octet-stream')
    post_fields.merge!({'file' => uploaded_file})
    request.set_form_data(post_fields)

    response = send_request(uri, request)
    handle_response(response)
  end
  private

  def send_request(uri, request)
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end
  end

  def handle_response(response)
    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)
    when Net::HTTPNotFound
      LoggerHelper.warn("Error: #{response.code} - #{response.message} - #{response.body}")
      JSON.parse(response.body)
    else
      LoggerHelper.warn("Error: #{response.code} - #{response.message} body: #{response.body}")
      raise "Error: #{response.code} - #{response.message} body: #{response.body}"
    end
  end
end

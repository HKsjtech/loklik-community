require 'net/http'
require 'uri'
require 'json'

class OpenApiHelper
  def initialize(base_url)
    @base_url = base_url
  end

  def get(endpoint, headers = {})
    uri = URI.join(@base_url, endpoint)
    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }

    response = send_request(uri, request)
    handle_response(response)
  end

  def post(endpoint, body, headers = {})
    uri = URI.join(@base_url, endpoint)
    request = Net::HTTP::Post.new(uri)
    headers.each { |key, value| request[key] = value }
    request.body = body.to_json

    response = send_request(uri, request)
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
      puts "Error: #{response.code} - #{response.message}"
      JSON.parse(response.body)
    else
      raise "Error: #{response.code} - #{response.message}"
    end
  end
end

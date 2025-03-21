require 'aws-sdk-s3'

module MyS3Helper
  def upload_file(file)
    # 处理上传的文件
    enable_s3_uploads = SiteSetting.enable_s3_uploads
    unless enable_s3_uploads
      raise "S3 upload not enabled."
    end

    # 获取 S3 配置
    s3_bucket = SiteSetting.s3_upload_bucket
    s3_access_key = SiteSetting.s3_access_key_id
    s3_secret_key = SiteSetting.s3_secret_access_key
    s3_region = SiteSetting.s3_region

    # 连接 S3
    s3 = Aws::S3::Resource.new(
      region: s3_region,
      access_key_id: s3_access_key,
      secret_access_key: s3_secret_key
    )

    # 获取当前日期，并格式化为 YYYY/MM/DD
    date_path = Time.now.strftime("%Y%m%d")
    # 生成随机文件名
    random_filename = "#{SecureRandom.hex(8)}_#{File.basename(file.original_filename)}"
    # 组合最终的 S3 文件路径
    s3_file_path = "#{date_path}/#{random_filename}"
    obj = s3.bucket(s3_bucket).object(s3_file_path)
    obj.upload_file(file.path,{ acl: 'public-read' })

    obj.public_url
  end
end

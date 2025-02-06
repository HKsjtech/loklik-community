# frozen_string_literal: true

class CreateAppVideoUpload < ActiveRecord::Migration[7.1]
  def change
    create_table :app_video_upload do |t|
      t.string :url, comment: '文件链接'
      t.string :original_name, comment: '文件原名字'
      t.bigint :file_size, comment: '文件大小'
      t.integer :thumbnail_width, comment: '缩略图宽度'
      t.integer :thumbnail_height, comment: '缩略图高度'
      t.string :extension, limit: 32, comment: '文件后缀'
      t.string :cover_img, comment: '封面图url'
      t.integer :is_deleted, default: 0, comment: '是否删除 0-正常 1-删除'

      t.timestamps default: -> { 'CURRENT_TIMESTAMP' }
    end
  end

end

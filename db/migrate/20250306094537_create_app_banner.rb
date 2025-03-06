# frozen_string_literal: true
class CreateAppBanner < ActiveRecord::Migration[7.1]
  def change
    create_table :app_banner do |t|
      t.string :name, comment: '名字'
      t.string :image_url, comment: '图片链接'
      t.string :link_url, comment: '调转地址'
      t.string :status, comment: '状态'
      t.integer :sort, comment: '排序'
      t.integer :update_user_id, comment: '修改人名字'
      t.string :update_name, comment: '修改人名字'

      t.timestamps default: -> { 'CURRENT_TIMESTAMP' }
    end
  end
end

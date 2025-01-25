# frozen_string_literal: true
class CreateAppUserExternalInfo < ActiveRecord::Migration[7.1]
  def change
    create_table :app_user_external_info do |t|
      t.integer :user_id, comment: '用户id'
      t.string :external_user_id, limit: 32, comment: '外部用户id'
      t.string :name, limit: 128, comment: '用户的名字'
      t.string :surname, limit: 128, comment: '用户的姓'
      t.string :avatar_url, limit: 256, comment: '用户头像'
      t.integer :is_upgrade, null: false, default: 0, comment: '是否升级 0-否 1-是'
      t.integer :is_deleted, default: 0, comment: '是否删除 0-正常 1-删除'
      t.timestamps default: -> { 'CURRENT_TIMESTAMP' }

      t.index [:user_id], unique: true
    end
  end
end

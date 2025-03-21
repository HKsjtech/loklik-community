# frozen_string_literal: true
class CreateAppUserFollow < ActiveRecord::Migration[7.1]
  def change
    create_table :app_user_follow do |t|
      t.integer :user_id, comment: '用户id'
      t.integer :target_user_id, comment: '关注用户id'
      t.integer :is_deleted, default: 0, comment: '是否删除 0-正常 1-删除'
      t.timestamps default: -> { 'CURRENT_TIMESTAMP' }

      t.index [:user_id, :target_user_id], unique: true
    end
  end
end

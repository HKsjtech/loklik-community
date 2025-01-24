# frozen_string_literal: true
class CreateAppUserCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :app_user_categories do |t|
      t.integer :user_id, comment: '用户id'
      t.integer :categories_id, comment: '分类id'
      t.integer :is_deleted, comment: '是否删除 0-正常 1-删除'

      t.timestamps default: -> { 'CURRENT_TIMESTAMP' }

      t.index [:user_id, :categories_id], unique: true
    end
  end
end

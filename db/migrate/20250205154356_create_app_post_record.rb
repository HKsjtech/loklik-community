# frozen_string_literal: true

class CreateAppPostRecord < ActiveRecord::Migration[7.1]
  def change
    create_table :app_post_record do |t|
      t.integer :post_id, comment: '帖子id'
      t.integer :is_deleted, default: 0, comment: '是否删除 0-正常 1-删除'

      t.timestamps default: -> { 'CURRENT_TIMESTAMP' }
    end
  end

end

# frozen_string_literal: true
class CreateAppUserTopicMaterialMap < ActiveRecord::Migration[7.1]
  def change
    create_table :app_user_topic_material_map do |t|
      t.integer :user_id, comment: '用户id'
      t.integer :topic_id, comment: '话题id'
      t.string :external_material_id, limit: 32, comment: '外部素材id'
      t.string :external_work_id, limit: 32, comment: '外部作品id'
      t.timestamps

      t.index [:topic_id], unique: true
    end
  end
end

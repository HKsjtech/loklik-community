class CreateAppCuratedTopic < ActiveRecord::Migration[6.1]
  def change
    create_table :app_curated_topic do |t|
      t.integer :topic_id, comment: '主题id'
      t.integer :is_curated,  default: 0, comment: '是否精选'
      t.integer :is_deleted,  default: 0, comment: '是否删除 0-正常 1-删除'
      t.string :created_name, limit: 64, comment: '创建人名字'
      t.string :update_name, limit: 64, comment: '修改人名字'

      t.timestamps
    end

    add_index :app_curated_topic, :topic_id, unique: true, name: 'app_curated_topic_topic_id_uindex'
  end
end

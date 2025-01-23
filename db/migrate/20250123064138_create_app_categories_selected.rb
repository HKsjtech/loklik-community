# frozen_string_literal: true
class CreateAppCategoriesSelected < ActiveRecord::Migration[7.2]
  def change
    create_table :app_categories_selected do |t|

      t.integer :categories_id, comment: '分类id'
      t.integer :sort, comment: '排序'
      t.integer :is_deleted, comment: '是否删除 0-正常 1-删除'

      t.timestamps default: -> { 'CURRENT_TIMESTAMP' }

      t.index :categories_id  # 如果需要，可以为 categories_id 添加索引
    end

    # 插入初始数据
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO app_categories_selected (id, categories_id, sort, is_deleted) VALUES (1, 0, 1, 0);
          INSERT INTO app_categories_selected (id, categories_id, sort, is_deleted) VALUES (2, 0, 2, 0);
          INSERT INTO app_categories_selected (id, categories_id, sort, is_deleted) VALUES (3, 0, 3, 0);
        SQL
      end
    end
  end
end

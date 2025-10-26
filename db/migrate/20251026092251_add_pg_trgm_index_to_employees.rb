class AddPgTrgmIndexToEmployees < ActiveRecord::Migration[8.0]
  def up
    # 啟用 PostgreSQL pg_trgm 擴展（用於模糊搜尋）
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    # 為員工姓名建立 GIN 索引，加速 ilike '%keyword%' 搜尋
    add_index :employees, :name, using: :gin, opclass: :gin_trgm_ops, name: 'index_employees_on_name_trgm'
  end

  def down
    remove_index :employees, name: 'index_employees_on_name_trgm'
    # 不移除擴展，因為可能有其他地方使用
  end
end

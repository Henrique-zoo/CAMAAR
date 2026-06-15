class CreatePerfis < ActiveRecord::Migration[8.1]
  def change
    create_table :perfil_adms do |t|
      t.references :usuario, null: false, foreign_key: true, index: { unique: true }
      t.references :departamento, foreign_key: true

      t.timestamps
    end

    create_table :perfil_docentes do |t|
      t.references :usuario, null: false, foreign_key: true, index: { unique: true }
      t.references :departamento, foreign_key: true

      t.timestamps
    end

    create_table :perfil_discentes do |t|
      t.references :usuario, null: false, foreign_key: true, index: { unique: true }
      t.string :matricula, null: false

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          INSERT INTO perfil_adms (usuario_id, departamento_id, created_at, updated_at)
          SELECT id, departamento_id, datetime('now'), datetime('now')
          FROM usuarios
          WHERE admin = 1
        SQL
      end
    end

    remove_column :usuarios, :admin, :boolean, default: false, null: false
  end
end

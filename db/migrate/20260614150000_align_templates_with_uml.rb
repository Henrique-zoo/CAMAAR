class AlignTemplatesWithUml < ActiveRecord::Migration[8.1]
  def up
    add_reference :templates, :perfil_adm, foreign_key: true

    execute <<~SQL.squish
      UPDATE templates
      SET perfil_adm_id = (
        SELECT perfil_adms.id
        FROM perfil_adms
        WHERE perfil_adms.usuario_id = templates.usuario_id
      )
      WHERE usuario_id IS NOT NULL
    SQL

    remove_reference :templates, :usuario, foreign_key: true
    rename_column :templates, :titulo, :nome
  end

  def down
    add_reference :templates, :usuario, foreign_key: true

    execute <<~SQL.squish
      UPDATE templates
      SET usuario_id = (
        SELECT perfil_adms.usuario_id
        FROM perfil_adms
        WHERE perfil_adms.id = templates.perfil_adm_id
      )
      WHERE perfil_adm_id IS NOT NULL
    SQL

    rename_column :templates, :nome, :titulo
    remove_reference :templates, :perfil_adm, foreign_key: true
  end
end

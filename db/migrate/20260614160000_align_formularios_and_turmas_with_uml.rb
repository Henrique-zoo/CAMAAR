class AlignFormulariosAndTurmasWithUml < ActiveRecord::Migration[8.1]
  def up
    add_reference :formularios, :perfil_adm, foreign_key: true
    add_reference :turmas, :formulario, foreign_key: true
    add_column :turmas, :numero, :integer
    add_column :turmas, :ano, :integer
    add_column :turmas, :periodo, :integer

    execute <<~SQL.squish
      UPDATE formularios
      SET perfil_adm_id = (
        SELECT perfil_adms.id
        FROM perfil_adms
        WHERE perfil_adms.usuario_id = formularios.usuario_id
      )
      WHERE usuario_id IS NOT NULL
    SQL

    execute <<~SQL.squish
      UPDATE turmas
      SET formulario_id = (
        SELECT formularios.id
        FROM formularios
        WHERE formularios.turma_id = turmas.id
      )
      WHERE EXISTS (
        SELECT 1
        FROM formularios
        WHERE formularios.turma_id = turmas.id
      )
    SQL

    remove_index :formularios, name: "index_formularios_on_template_id_and_turma_id"
    remove_reference :formularios, :turma, foreign_key: true
    remove_reference :formularios, :usuario, foreign_key: true
    remove_column :formularios, :nome, :string

    change_column_null :formularios, :perfil_adm_id, false
  end

  def down
    add_column :formularios, :nome, :string
    add_reference :formularios, :usuario, foreign_key: true
    add_reference :formularios, :turma, foreign_key: true

    execute <<~SQL.squish
      UPDATE formularios
      SET usuario_id = (
        SELECT perfil_adms.usuario_id
        FROM perfil_adms
        WHERE perfil_adms.id = formularios.perfil_adm_id
      )
      WHERE perfil_adm_id IS NOT NULL
    SQL

    execute <<~SQL.squish
      UPDATE formularios
      SET turma_id = (
        SELECT turmas.id
        FROM turmas
        WHERE turmas.formulario_id = formularios.id
      )
      WHERE EXISTS (
        SELECT 1
        FROM turmas
        WHERE turmas.formulario_id = formularios.id
      )
    SQL

    add_index :formularios, %i[template_id turma_id], unique: true

    remove_reference :turmas, :formulario, foreign_key: true
    remove_column :turmas, :periodo, :integer
    remove_column :turmas, :ano, :integer
    remove_column :turmas, :numero, :integer
    remove_reference :formularios, :perfil_adm, foreign_key: true
  end
end

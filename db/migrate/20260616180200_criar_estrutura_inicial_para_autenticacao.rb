class CriarEstruturaInicialParaAutenticacao < ActiveRecord::Migration[8.1]
  def change
    drop_table :participacoes_turma, if_exists: true
    drop_table :perfis_discente, if_exists: true
    drop_table :perfis_docente, if_exists: true
    drop_table :turmas, if_exists: true
    drop_table :materias, if_exists: true
    drop_table :perfis_adm, if_exists: true
    drop_table :tokens, if_exists: true
    drop_table :departamentos, if_exists: true
    drop_table :usuarios, if_exists: true

    create_table :usuarios do |t|
      t.string  :matricula,       null: false
      t.string  :email
      t.string  :senha_digest
      t.integer :status,          default: 0, null: false
      t.string  :nome
    end
    add_index :usuarios, :matricula, unique: true

    create_table :departamentos do |t|
      t.string :nome
    end

    create_table :tokens do |t|
      t.string   :value,          null: false
      t.string   :tipo,           null: false
      t.datetime :expires_at,     null: false
      t.string   :matricula_aluno, null: false
      t.timestamps
    end
    add_index :tokens, :value, unique: true

    create_table :perfis_adm, id: false do |t|
      t.primary_key :id
      t.references  :departamento, null: false, foreign_key: true
    end
    add_foreign_key :perfis_adm, :usuarios, column: :id

    create_table :perfis_docente, id: false do |t|
      t.primary_key :id
      t.references  :departamento, null: false, foreign_key: true
    end
    add_foreign_key :perfis_docente, :usuarios, column: :id

    create_table :perfis_discente, id: false do |t|
      t.primary_key :id
    end
    add_foreign_key :perfis_discente, :usuarios, column: :id

    create_table :materias do |t|
      t.string     :codigo
      t.string     :nome
      t.references :departamento, null: false, foreign_key: true
    end

    create_table :turmas do |t|
      t.integer    :numero
      t.integer    :ano
      t.integer    :semestre
      t.references :materia, null: false, foreign_key: true
    end

    create_table :participacoes_turma do |t|
      t.references :usuario, null: false, foreign_key: true
      t.references :turma,   null: false, foreign_key: true
    end
  end
end

class CreateFormulariosAndQuestoesFormulario < ActiveRecord::Migration[8.1]
  def change
    create_table :formularios do |t|
      t.string :nome
      t.references :template, null: false, foreign_key: true
      t.references :turma, null: false, foreign_key: true
      t.references :usuario, null: false, foreign_key: true

      t.timestamps
    end

    add_index :formularios, %i[template_id turma_id], unique: true

    create_table :questoes_formulario do |t|
      t.references :formulario, null: false, foreign_key: true
      t.text :enunciado, null: false
      t.string :tipo, null: false
      t.json :opcoes
      t.boolean :obrigatoria, default: false, null: false
      t.integer :posicao, null: false

      t.timestamps
    end
  end
end

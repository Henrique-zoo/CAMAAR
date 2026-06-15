class CreateTemplatesAndQuestoes < ActiveRecord::Migration[8.1]
  def change
    create_table :templates do |t|
      t.string :titulo, null: false
      t.text :descricao
      t.references :usuario, foreign_key: true

      t.timestamps
    end

    create_table :questoes do |t|
      t.references :template, null: false, foreign_key: true
      t.text :enunciado, null: false
      t.string :tipo, null: false
      t.json :opcoes
      t.boolean :obrigatoria, default: false, null: false
      t.integer :posicao, null: false

      t.timestamps
    end
  end
end

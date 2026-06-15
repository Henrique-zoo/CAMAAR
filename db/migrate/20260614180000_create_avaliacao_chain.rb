class CreateAvaliacaoChain < ActiveRecord::Migration[8.1]
  def change
    create_table :avaliacoes do |t|
      t.references :participacao_turma, null: false, foreign_key: true
      t.references :formulario, null: false, foreign_key: true
      t.datetime :respondido_em

      t.timestamps
    end

    create_table :respostas do |t|
      t.references :avaliacao, null: false, foreign_key: true
      t.references :questao, null: false, foreign_key: true

      t.timestamps
    end

    create_table :opcoes_escolhidas do |t|
      t.references :resposta, null: false, foreign_key: true, index: { unique: true }
      t.references :opcao, null: false, foreign_key: true

      t.timestamps
    end

    create_table :textos do |t|
      t.references :resposta, null: false, foreign_key: true, index: { unique: true }
      t.text :texto, null: false

      t.timestamps
    end
  end
end

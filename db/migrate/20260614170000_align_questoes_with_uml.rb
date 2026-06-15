class AlignQuestoesWithUml < ActiveRecord::Migration[8.1]
  def up
    add_reference :questoes, :formulario, foreign_key: true
    add_column :questoes, :tipo_novo, :integer

    execute <<~SQL.squish
      UPDATE questoes
      SET tipo_novo = CASE
        WHEN tipo = 'multipla_escolha' THEN 0
        ELSE 1
      END
    SQL

    create_table :opcoes do |t|
      t.references :questao, null: false, foreign_key: true
      t.string :texto, null: false

      t.timestamps
    end

    questoes_formulario_rows.each do |row|
      questao_id = insert_questao_formulario(row)
      insert_opcoes(questao_id, row["opcoes"])
    end

    change_column_null :questoes, :tipo_novo, false
    remove_column :questoes, :tipo, :string
    rename_column :questoes, :tipo_novo, :tipo
    change_column_null :questoes, :template_id, true
    drop_table :questoes_formulario
  end

  def down
    create_table :questoes_formulario do |t|
      t.references :formulario, null: false, foreign_key: true
      t.text :enunciado, null: false
      t.string :tipo, null: false
      t.json :opcoes
      t.boolean :obrigatoria, default: false, null: false
      t.integer :posicao, null: false

      t.timestamps
    end

    questoes_formulario_backfill

    drop_table :opcoes
    remove_reference :questoes, :formulario, foreign_key: true
    rename_column :questoes, :tipo, :tipo_novo
    add_column :questoes, :tipo, :string

    execute <<~SQL.squish
      UPDATE questoes
      SET tipo = CASE
        WHEN tipo_novo = 0 THEN 'multipla_escolha'
        ELSE 'texto'
      END
    SQL

    change_column_null :questoes, :tipo, false
    remove_column :questoes, :tipo_novo, :integer
    change_column_null :questoes, :template_id, false
  end

  private

  def questoes_formulario_rows
    connection.select_all("SELECT * FROM questoes_formulario ORDER BY id")
  end

  def insert_questao_formulario(row)
    tipo = row["tipo"] == "multipla_escolha" ? 0 : 1
    now = connection.quote(Time.current)

    connection.insert <<~SQL.squish
      INSERT INTO questoes
        (formulario_id, template_id, enunciado, tipo_novo, obrigatoria, posicao, created_at, updated_at)
      VALUES
        (#{row["formulario_id"]}, NULL, #{connection.quote(row["enunciado"])}, #{tipo},
         #{row["obrigatoria"] ? 1 : 0}, #{row["posicao"]}, #{now}, #{now})
    SQL
  end

  def insert_opcoes(questao_id, opcoes_json)
    return if opcoes_json.blank?

    opcoes = JSON.parse(opcoes_json)
    now = connection.quote(Time.current)

    opcoes.each do |texto|
      connection.execute <<~SQL.squish
        INSERT INTO opcoes (questao_id, texto, created_at, updated_at)
        VALUES (#{questao_id}, #{connection.quote(texto)}, #{now}, #{now})
      SQL
    end
  end

  def questoes_formulario_backfill
    questoes = connection.select_all(<<~SQL.squish)
      SELECT questoes.*, GROUP_CONCAT(opcoes.texto) AS opcoes_textos
      FROM questoes
      LEFT JOIN opcoes ON opcoes.questao_id = questoes.id
      WHERE questoes.formulario_id IS NOT NULL
      GROUP BY questoes.id
    SQL

    questoes.each do |questao|
      tipo = questao["tipo"].to_i == 0 ? "multipla_escolha" : "texto"
      opcoes = questao["opcoes_textos"]&.split(",") || []
      now = connection.quote(Time.current)

      connection.execute <<~SQL.squish
        INSERT INTO questoes_formulario
          (formulario_id, enunciado, tipo, opcoes, obrigatoria, posicao, created_at, updated_at)
        VALUES
          (#{questao["formulario_id"]}, #{connection.quote(questao["enunciado"])}, #{connection.quote(tipo)},
           #{connection.quote(opcoes.to_json)}, #{questao["obrigatoria"] ? 1 : 0}, #{questao["posicao"]},
           #{now}, #{now})
      SQL
    end
  end
end

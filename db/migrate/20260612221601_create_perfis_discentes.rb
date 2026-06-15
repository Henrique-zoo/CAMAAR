class CreatePerfisDiscentes < ActiveRecord::Migration[8.1]
  def change
    create_table :perfis_discentes, id: false do |t|
      t.primary_key :id
      t.string :matricula, null: false

      t.timestamps
    end

    add_index :perfis_discentes, :matricula, unique: true
    add_foreign_key :perfis_discentes, :usuarios, column: :id
  end
end

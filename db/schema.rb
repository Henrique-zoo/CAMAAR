# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_16_180200) do
  create_table "departamentos", force: :cascade do |t|
    t.string "nome"
  end

  create_table "materias", force: :cascade do |t|
    t.string "codigo"
    t.integer "departamento_id", null: false
    t.string "nome"
    t.index ["departamento_id"], name: "index_materias_on_departamento_id"
  end

  create_table "participacoes_turma", force: :cascade do |t|
    t.integer "turma_id", null: false
    t.integer "usuario_id", null: false
    t.index ["turma_id"], name: "index_participacoes_turma_on_turma_id"
    t.index ["usuario_id"], name: "index_participacoes_turma_on_usuario_id"
  end

  create_table "perfis_adm", force: :cascade do |t|
    t.integer "departamento_id", null: false
    t.index ["departamento_id"], name: "index_perfis_adm_on_departamento_id"
  end

  create_table "perfis_discente", force: :cascade do |t|
  end

  create_table "perfis_docente", force: :cascade do |t|
    t.integer "departamento_id", null: false
    t.index ["departamento_id"], name: "index_perfis_docente_on_departamento_id"
  end

  create_table "tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "matricula_aluno", null: false
    t.string "tipo", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index ["value"], name: "index_tokens_on_value", unique: true
  end

  create_table "turmas", force: :cascade do |t|
    t.integer "ano"
    t.integer "materia_id", null: false
    t.integer "numero"
    t.integer "semestre"
    t.index ["materia_id"], name: "index_turmas_on_materia_id"
  end

  create_table "usuarios", force: :cascade do |t|
    t.string "email"
    t.string "matricula", null: false
    t.string "nome"
    t.string "senha_digest"
    t.integer "status", default: 0, null: false
    t.index ["matricula"], name: "index_usuarios_on_matricula", unique: true
  end

  add_foreign_key "materias", "departamentos"
  add_foreign_key "participacoes_turma", "turmas"
  add_foreign_key "participacoes_turma", "usuarios"
  add_foreign_key "perfis_adm", "departamentos"
  add_foreign_key "perfis_adm", "usuarios", column: "id"
  add_foreign_key "perfis_discente", "usuarios", column: "id"
  add_foreign_key "perfis_docente", "departamentos"
  add_foreign_key "perfis_docente", "usuarios", column: "id"
  add_foreign_key "turmas", "materias"
end

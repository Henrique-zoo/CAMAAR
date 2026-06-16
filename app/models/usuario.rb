# app/models/usuario.rb
class Usuario < ApplicationRecord
  has_secure_password :senha, validations: false

  has_many :tokens,
    foreign_key: :matricula_aluno,
    primary_key: :matricula,
    dependent:   :delete_all

  # ↓ foreign_key: :id diz ao Rails para buscar WHERE perfis_adm.id = usuarios.id
  has_one :perfil_adm,
    foreign_key: :id,
    dependent:   :destroy

  has_one :perfil_docente,
    foreign_key: :id,
    dependent:   :destroy

  has_one :perfil_discente,
    foreign_key: :id,
    dependent:   :destroy

  has_many :participacoes_turma, dependent: :destroy
  has_many :turmas, through: :participacoes_turma

  validates :matricula, presence: true, uniqueness: true

  def admin?
    perfil_adm.present?
  end
end

# frozen_string_literal: true

class Turma < ApplicationRecord
  enum :semestre, {
    primeiro: 1,
    segundo: 2,
    verao: 4
  }

  belongs_to :materia,
    class_name: "Materia",
    inverse_of: :turmas

  has_many :participacoes_turma,
    class_name: "ParticipacaoTurma",
    dependent: :restrict_with_error,
    inverse_of: :turma

  has_many :usuarios,
    through: :participacoes_turma

  has_many :formularios,
    class_name: "Formulario",
    dependent: :restrict_with_error,
    inverse_of: :turma

  has_many :avaliacoes,
    through: :formularios

  validates :numero,
    presence: true,
    numericality: { only_integer: true, greater_than: 0 }

  validates :ano,
    presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 2000 }

  validates :semestre, presence: true
  validates :materia, presence: true

  validates :numero,
    uniqueness: {
      scope: %i[ano semestre materia_id],
      message: "já existe para esta matéria, ano e semestre"
    }

  scope :do_departamento, ->(departamento) {
    joins(:materia).where(materias: { departamento_id: departamento.id })
  }

  def departamento
    materia.departamento
  end

  def departamento_id
    materia.departamento_id
  end

  def participantes_docentes
    participacoes_turma.docentes
  end

  def participantes_discentes
    participacoes_turma.discentes
  end
end

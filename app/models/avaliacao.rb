# frozen_string_literal: true

class Avaliacao < ApplicationRecord
  belongs_to :participacao_turma,
    class_name: "ParticipacaoTurma",
    inverse_of: :avaliacoes

  belongs_to :formulario,
    class_name: "Formulario",
    inverse_of: :avaliacoes

  has_many :respostas,
    class_name: "Resposta",
    dependent: :destroy,
    inverse_of: :avaliacao

  validates :participacao_turma, presence: true
  validates :formulario, presence: true

  validates :participacao_turma_id,
    uniqueness: {
      scope: :formulario_id,
      message: "já possui avaliação para este formulário"
    }

  validate :participacao_deve_ser_da_turma_do_formulario
  validate :participacao_deve_corresponder_ao_publico_alvo

  scope :respondidas, -> {
    where.not(respondido_em: nil)
  }

  scope :pendentes, -> {
    where(respondido_em: nil)
  }

  def respondida?
    respondido_em.present?
  end

  def pendente?
    !respondida?
  end

  def marcar_como_respondida!
    update!(respondido_em: Time.current)
  end

  private

  def participacao_deve_ser_da_turma_do_formulario
    return if participacao_turma.blank?
    return if formulario.blank?
    return if participacao_turma.turma_id == formulario.turma_id

    errors.add(:participacao_turma, "deve pertencer à turma do formulário")
  end

  def participacao_deve_corresponder_ao_publico_alvo
    return if participacao_turma.blank?
    return if formulario.blank?
    return if participacao_turma.corresponde_ao_publico?(formulario.publico_alvo)

    errors.add(:participacao_turma, "não corresponde ao público-alvo do formulário")
  end
end

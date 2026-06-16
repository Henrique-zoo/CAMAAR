class AvaliacoesController < ApplicationController
  before_action :require_login

  def pendentes
    turmas_ids = ParticipacaoTurma
                   .where(usuario: current_usuario)
                   .pluck(:turma_id)

    @avaliacoes_pendentes = Avaliacao
                              .pendentes
                              .joins(:participacao_turma)
                              .where(participacoes_turmas: { turma_id: turmas_ids })
                              .includes(formulario: { turma: :materia })
  end

  private

  def require_login
    redirect_to root_path, alert: 'Usuário não autenticado' unless current_usuario
  end
end
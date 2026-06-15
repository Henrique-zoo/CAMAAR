class AvaliacoesController < ApplicationController
  def pendentes
    # Simulando o usuário logado provisoriamente
    usuario_atual = defined?(current_usuario) ? current_usuario : Usuario.first

    @avaliacoes_pendentes = Avaliacao.pendentes
                                     .joins(:participacao_turma)
                                     .where(participacoes_turmas: { usuario_id: usuario_atual.id })
                                     .includes(formulario: { turma: :materia })
  end
end
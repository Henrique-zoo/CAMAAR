class AvaliacoesController < ApplicationController
  before_action :require_login
  before_action :set_avaliacao, only: %i[responder submeter]  # ← linha nova

  def pendentes
    # ← sem alteração, exatamente como está na HU13
    turmas_ids = ParticipacaoTurma
                   .where(usuario: current_usuario)
                   .pluck(:turma_id)

    @avaliacoes_pendentes = Avaliacao
                              .pendentes
                              .joins(:participacao_turma)
                              .where(participacoes_turmas: { turma_id: turmas_ids })
                              .includes(formulario: { turma: :materia })
  end

  # ← tudo abaixo é novo da HU14
  def responder
    if @avaliacao.respondida?
      redirect_to pendentes_avaliacoes_path,
                  alert: 'Esta avaliação já foi respondida.'
      return
    end

    @formulario = @avaliacao.formulario
    @questoes   = questoes_do_formulario
  end

  def submeter
    if @avaliacao.respondida?
      redirect_to pendentes_avaliacoes_path,
                  alert: 'Esta avaliação já foi respondida.'
      return
    end

    @formulario = @avaliacao.formulario
    @questoes   = questoes_do_formulario

    if todas_obrigatorias_preenchidas?
      salvar_respostas_e_finalizar
    else
      flash.now[:alert] = 'Todas as questões obrigatórias devem ser preenchidas.'
      render :responder, status: :unprocessable_entity
    end
  end

  private

  def require_login
    redirect_to root_path, alert: 'Usuário não autenticado' unless current_usuario
  end

  def set_avaliacao
    participacao_ids = ParticipacaoTurma
                         .where(usuario: current_usuario)
                         .pluck(:id)

    @avaliacao = Avaliacao.find_by!(id: params[:id],
                                    participacao_turma_id: participacao_ids)
  rescue ActiveRecord::RecordNotFound
    redirect_to pendentes_avaliacoes_path, alert: 'Avaliação não encontrada.'
  end

  def questoes_do_formulario
    template = @formulario.template
    return Questao.none unless template

    template.questoes
            .includes(:opcoes)
            .order('utilizacoes_questoes.numero')
  end

  def todas_obrigatorias_preenchidas?
    respostas_params = params[:respostas] || {}

    @questoes.all? do |questao|
      resposta = respostas_params[questao.id.to_s] || {}

      if questao.discursiva?
        resposta[:texto].to_s.strip.present?
      else
        Array(resposta[:opcao_id]).any?(&:present?)
      end
    end
  end

  def salvar_respostas_e_finalizar
    ActiveRecord::Base.transaction do
      respostas_params = params[:respostas] || {}

      @questoes.each do |questao|
        resposta_data = respostas_params[questao.id.to_s] || {}
        resposta = Resposta.find_or_initialize_by(avaliacao: @avaliacao, questao: questao)
        resposta.save!

        if questao.discursiva?
          Texto.find_or_initialize_by(resposta: resposta)
               .update!(texto: resposta_data[:texto].to_s.strip)
        else
          opcao_id = resposta_data[:opcao_id].to_s
          opcao    = questao.opcoes.find(opcao_id)
          OpcaoEscolhida.find_or_create_by!(resposta: resposta, opcao: opcao)
        end
      end

      @avaliacao.marcar_como_respondida!
    end

    redirect_to pendentes_avaliacoes_path,
                notice: 'Avaliação registrada com sucesso.'
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = 'Todas as questões obrigatórias devem ser preenchidas.'
    render :responder, status: :unprocessable_entity
  end
end
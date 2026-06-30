# frozen_string_literal: true

class AvaliacoesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_avaliacao, only: %i[responder submeter]

  # == Descrição
  # Lista todas as avaliações pendentes que pertencem às turmas nas quais o usuário autenticado está matriculado.
  #
  # == Argumentos
  # * Nenhum. Consome indiretamente o +current_user.id+ da sessão.
  #
  # == Retorno
  # * Renderiza a view +pendentes+.
  # * Popula a variável de instância +@avaliacoes_pendentes+ com a coleção de avaliações.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: Realiza apenas operações de leitura (SELECT), cruzando +Avaliacao+, +ParticipacaoTurma+ e +Formulario+.
  # * *Redirecionamento*: Bloqueia e redireciona caso o usuário não esteja autenticado (via +before_action+).
  def pendentes
    @avaliacoes_pendentes = Avaliacao
      .pendentes
      .joins(:participacao_turma)
      .where(participacoes_turmas: { usuario_id: current_user.id })
      .includes(formulario: { turma: :materia })
  end

  # == Descrição
  # Prepara e exibe a tela contendo o formulário e as questões para que o discente possa responder à avaliação.
  #
  # == Argumentos
  # * Recebe o ID da avaliação através de +params[:id]+ (processado no +before_action+).
  #
  # == Retorno
  # * Renderiza a view +responder+.
  # * Popula as variáveis de instância +@formulario+ e +@questoes+.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: Apenas leitura.
  # * *Redirecionamento*: Se a avaliação já constar como respondida, interrompe o fluxo e redireciona para a lista de pendentes com um alerta.
  def responder
    if @avaliacao.respondida?
      redirect_to avaliacoes_pendentes_path,
        alert: "Esta avaliação já foi respondida."
      return
    end

    @formulario = @avaliacao.formulario
    @questoes   = questoes_do_formulario
  end

  # == Descrição
  # Processa a submissão do formulário preenchido pelo discente, validando se as regras foram cumpridas 
  # antes de repassar para a transação de salvamento.
  #
  # == Argumentos
  # * Recebe os dados do formulário preenchido através do +params[:respostas]+.
  # * Recebe o ID da avaliação via +params[:id]+ (processado no +before_action+).
  #
  # == Retorno
  # * Em caso de sucesso: Chama o método de salvamento que redireciona o usuário.
  # * Em caso de falha de validação: Renderiza novamente a view +responder+ com status HTTP +unprocessable_entity+.
  #
  # == Efeitos Colaterais
  # * *Redirecionamento*: Redireciona para a lista de pendentes caso a avaliação já tenha sido respondida previamente.
  # * *Banco de Dados*: Não altera o banco diretamente neste escopo, repassando a responsabilidade de escrita para +salvar_respostas_e_finalizar+.
  def submeter
    if @avaliacao.respondida?
      redirect_to avaliacoes_pendentes_path,
        alert: "Esta avaliação já foi respondida."
      return
    end

    @formulario = @avaliacao.formulario
    @questoes   = questoes_do_formulario

    if todas_obrigatorias_preenchidas?
      salvar_respostas_e_finalizar
    else
      flash.now[:alert] = "Todas as questões obrigatórias devem ser preenchidas."
      render :responder, status: :unprocessable_entity
    end
  end

  private

  # == Descrição
  # Método de segurança que busca a avaliação solicitada e garante que ela pertence às turmas do usuário atual.
  #
  # == Argumentos
  # * Consome +params[:id]+ da rota atual.
  # * Consome o usuário logado via +current_user+.
  #
  # == Retorno
  # * Configura a variável de instância +@avaliacao+.
  #
  # == Efeitos Colaterais
  # * *Redirecionamento*: Se a avaliação não for encontrada ou não pertencer ao usuário, resgata a exceção +ActiveRecord::RecordNotFound+ e redireciona com alerta.
  def set_avaliacao
    participacao_ids = ParticipacaoTurma
                         .where(usuario: current_user)
                         .pluck(:id)

    @avaliacao = Avaliacao.find_by!(id: params[:id],
                                    participacao_turma_id: participacao_ids)
  rescue ActiveRecord::RecordNotFound
    redirect_to avaliacoes_pendentes_path, alert: "Avaliação não encontrada."
  end

  # == Descrição
  # Busca as questões atreladas ao template do formulário atual, ordenando-as conforme a configuração.
  #
  # == Argumentos
  # * Nenhum diretamente. Utiliza a instância atual de +@formulario+.
  #
  # == Retorno
  # * Retorna um +ActiveRecord::Relation+ contendo as questões e suas opções de resposta, ou uma coleção vazia caso não haja template.
  #
  # == Efeitos Colaterais
  # * Nenhum (apenas leitura em banco).
  def questoes_do_formulario
    template = @formulario.template
    return Questao.none unless template

    template.questoes
            .includes(:opcoes)
            .order("utilizacoes_questoes.numero")
  end

  # == Descrição
  # Verifica interativamente se todas as questões listadas no formulário receberam um preenchimento válido nos parâmetros submetidos.
  #
  # == Argumentos
  # * Consome os dados preenchidos pelo usuário através de +params[:respostas]+.
  #
  # == Retorno
  # * Retorna um booleano (+true+ se todas estiverem preenchidas corretamente, +false+ caso falte alguma).
  #
  # == Efeitos Colaterais
  # * Nenhum. Operação estrita de processamento em memória.
  def todas_obrigatorias_preenchidas?
    respostas_params = params[:respostas] || {}

    @questoes.all? do |questao|
      resposta = respostas_params[questao.id.to_s] || {}

      if questao.discursiva?
        resposta["texto"].to_s.strip.present?
      else
        Array(resposta["opcao_id"]).any?(&:present?)
      end
    end
  end

  # == Descrição
  # Executa a gravação das respostas do discente em uma transação segura, garantindo integridade dos dados e finalizando a avaliação.
  #
  # == Argumentos
  # * Consome os dados validados de +params[:respostas]+.
  #
  # == Retorno
  # * Em sucesso: Redireciona para +avaliacoes_pendentes_path+ com mensagem de sucesso.
  # * Em caso de erro do banco de dados (+RecordInvalid+ ou +RecordNotFound+): Re-renderiza a view +responder+.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: Abre uma transação no banco. Cria registros na tabela +Resposta+ e em tabelas polimórficas associadas (+Texto+ ou +OpcaoEscolhida+). Atualiza a +Avaliacao+ marcando-a como respondida.
  def salvar_respostas_e_finalizar
    ActiveRecord::Base.transaction do
      respostas_params = params[:respostas] || {}

      @questoes.each do |questao|
        resposta_data = respostas_params[questao.id.to_s] || {}
        resposta = Resposta.find_or_initialize_by(avaliacao: @avaliacao, questao: questao)

        if questao.discursiva?
          resposta.build_texto(texto: resposta_data["texto"].to_s.strip)
        else
          opcao_id = resposta_data["opcao_id"].to_s
          opcao    = questao.opcoes.find(opcao_id)
          resposta.opcoes_escolhidas.build(opcao: opcao)
        end

        resposta.save!
      end

      @avaliacao.marcar_como_respondida!
    end

    redirect_to avaliacoes_pendentes_path,
      notice: "Avaliação registrada com sucesso."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    flash.now[:alert] = "Todas as questões obrigatórias devem ser preenchidas."
    render :responder, status: :unprocessable_entity
  end
end
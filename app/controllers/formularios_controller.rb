# frozen_string_literal: true

require "csv"

class FormulariosController < ApplicationController
  before_action :authenticate_user!
  before_action :require_administrador!, except: :exportar_csv
  before_action :require_administrador_para_exportacao!, only: :exportar_csv

  # == Descrição
  # Lista todos os formulários vinculados ao departamento do administrador logado referentes ao semestre letivo atual.
  #
  # == Argumentos
  # * Nenhum argumento explícito. Consome +current_administrador+ do contexto da sessão.
  #
  # == Retorno
  # * Popula a variável de instância +@formularios+ com uma coleção filtrada de objetos +Formulario+.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: Realiza apenas operações de leitura (SELECT), aplicando escopos específicos e eager loading (+includes+) para otimizar a consulta.
  def index
    @formularios = Formulario
      .do_departamento(current_administrador.departamento)
      .do_semestre_atual
      .recentes
      .includes(:template, turma: :materia)
  end

  # == Descrição
  # Prepara as variáveis necessárias para a interface de criação de formulários, listando os templates e as turmas elegíveis.
  #
  # == Argumentos
  # * Nenhum.
  #
  # == Retorno
  # * Popula a variável +@templates+ com todos os templates do sistema.
  # * Popula a variável +@turmas+ com as turmas do semestre atual que ainda não possuem formulários vinculados.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: Realiza apenas operações de leitura nas tabelas +Template+ e +Turma+.
  def new
    @templates = Template.all
    @turmas = Turma.do_semestre_atual.sem_formulario.includes(:materia)
  end

  # == Descrição
  # Valida os parâmetros iniciais de escolha do template e turmas, salvando os dados temporariamente na sessão do usuário.
  #
  # == Argumentos
  # * Consome +params[:template_id]+ contendo o ID do template de formulário escolhido.
  # * Consome +params[:turma_ids]+ contendo um array ou valor isolado com os IDs das turmas selecionadas.
  #
  # == Retorno
  # * Em caso de sucesso: Redireciona o fluxo para a rota +publicar_formularios_path+.
  # * Em caso de erro de validação (+Formularios::Error+): Redireciona de volta para +new_formulario_path+ exibindo a mensagem tratada.
  #
  # == Efeitos Colaterais
  # * *Sessão*: Modifica o estado do hash de sessão criando a chave +session[:formulario_preparacao]+.
  # * *Redirecionamento*: Altera o fluxo de navegação HTTP.
  def preparar
    Formularios::CreateFromTemplate.validate_preparacao!(
      template_id: params[:template_id],
      turma_ids: params[:turma_ids]
    )

    session[:formulario_preparacao] = {
      "template_id" => params[:template_id].to_i,
      "turma_ids" => Array(params[:turma_ids]).map(&:to_i)
    }

    redirect_to publicar_formularios_path
  rescue Formularios::Error => e
    redirect_to new_formulario_path, alert: e.message
  end

  # == Descrição
  # Exibe a tela de revisão final para o administrador definir o público-alvo antes de persistir o formulário.
  #
  # == Argumentos
  # * Nenhum diretamente via parâmetros de URL. Consome os dados salvos anteriormente em +session[:formulario_preparacao]+.
  #
  # == Retorno
  # * Popula a variável +@template+ com a instância encontrada.
  # * Popula +@turmas+ com a lista de turmas que receberão o formulário.
  #
  # == Efeitos Colaterais
  # * *Redirecionamento*: Se o hash de sessão de preparação estiver vazio, força o redirecionamento de segurança de volta para +new_formulario_path+.
  # * *Banco de Dados*: Apenas consultas de leitura.
  def publicar
    preparacao = session[:formulario_preparacao]
    unless preparacao
      redirect_to new_formulario_path
      return
    end

    @template = Template.find(preparacao["template_id"])
    @turmas = Turma.where(id: preparacao["turma_ids"]).includes(:materia)
  end

  # == Descrição
  # Processa e executa a criação definitiva dos registros de formulário no banco de dados através da classe de serviço especialista.
  #
  # == Argumentos
  # * Consome o hash contido em +session[:formulario_preparacao]+.
  # * Consome +params[:publico_alvo]+ vindo da requisição POST.
  #
  # == Retorno
  # * Redireciona para +new_formulario_path+ acompanhado de mensagens de sucesso (+notice+) ou falha (+alert+).
  # * Redireciona para +publicar_formularios_path+ se o erro for estritamente relacionado à ausência de público-alvo.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: Insere múltiplos novos registros na tabela +Formulario+ através do service object.
  # * *Sessão*: Executa a limpeza dos dados temporários utilizando o método +session.delete(:formulario_preparacao)+.
  def create
    preparacao = session[:formulario_preparacao]
    unless preparacao
      redirect_to new_formulario_path, alert: "Selecione um template e as turmas antes de publicar"
      return
    end

    Formularios::CreateFromTemplate.call(
      template_id: preparacao["template_id"],
      turma_ids: preparacao["turma_ids"],
      publico_alvo: params[:publico_alvo],
      perfil_adm: current_administrador
    )

    session.delete(:formulario_preparacao)

    redirect_to new_formulario_path,
      notice: "Formulário criado com sucesso para as turmas selecionadas"
  rescue Formularios::Error => e
    if e.message == Formularios::CreateFromTemplate::SEM_PUBLICO_ALVO
      redirect_to publicar_formularios_path, alert: e.message
    else
      session.delete(:formulario_preparacao)
      redirect_to new_formulario_path, alert: e.message
    end
  end

  # == Descrição
  # Compila todas as avaliações feitas pelos discentes em um formulário específico e monta um fluxo de dados estruturado em formato CSV para download imediato.
  #
  # == Argumentos
  # * Recebe o ID do formulário alvo através de +params[:id]+.
  #
  # == Retorno
  # * Dispara o download de um arquivo de texto compactado em formato CSV (+text/csv; charset=utf-8+) contendo as respostas nominais.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: Realiza consultas pesadas de leitura cruzando dados de +Avaliacao+, +Resposta+, +Texto+ e +OpcaoEscolhida+.
  # * *Interface*: Injeta cabeçalhos customizados na resposta HTTP para forçar a ação de download no navegador (+send_data+).
  def exportar_csv
    @formulario = Formulario.find(params[:id])
    avaliacoes = @formulario.avaliacoes
      .joins(:respostas)
      .distinct
      .includes(
        participacao_turma: :usuario,
        respostas: [ :questao, :texto, { opcoes_escolhidas: :opcao } ]
      )

    questoes = @formulario.template.questoes.order("utilizacoes_questoes.numero")
    csv_data = CSV.generate(headers: true, col_sep: ";") do |csv|
      csv << [ "Aluno", "Matrícula", *questoes.map(&:enunciado) ]

      avaliacoes.each do |avaliacao|
        csv << linha_csv(avaliacao, questoes)
      end
    end

    send_data csv_data,
      filename: "resultados_turma_#{@formulario.turma.materia.codigo}_#{Date.current}.csv",
      type: "text/csv; charset=utf-8"
  end

  private

  # == Descrição
  # Filtro de segurança privado executado antes da exportação para garantir o bloqueio de acessos não autorizados.
  #
  # == Argumentos
  # * Nenhum diretamente. Utiliza as propriedades do objeto +current_user+.
  #
  # == Retorno
  # * Retorna +nil+ caso a validação passe com sucesso.
  #
  # == Efeitos Colaterais
  # * *Redirecionamento*: Interrompe bruscamente o ciclo da requisição e redireciona para +avaliacoes_pendentes_path+ com um alerta caso o usuário não seja um administrador.
  def require_administrador_para_exportacao!
    return if current_user&.administrador?

    redirect_to avaliacoes_pendentes_path,
      alert: "Apenas administradores possuem acesso a este recurso"
  end

  # == Descrição
  # Método utilitário privado que traduz uma instância de avaliação e suas respectivas respostas em uma linha compatível com o CSV.
  #
  # == Argumentos
  # * +avaliacao+: Instância do modelo +Avaliacao+.
  # * +questoes+: Coleção ou array contendo os objetos ordenados de +Questao+.
  #
  # == Retorno
  # * Retorna um objeto +Array+ cujas primeiras posições são os dados de identificação do aluno seguidos por suas respostas textuais.
  #
  # == Efeitos Colaterais
  # * Nenhum. Processamento puro em memória ram.
  def linha_csv(avaliacao, questoes)
    usuario = avaliacao.participacao_turma.usuario
    linha = [ usuario.nome, usuario.matricula.presence || "N/A" ]

    questoes.each do |questao|
      resposta = avaliacao.respostas.find { |item| item.questao_id == questao.id }
      linha << valor_resposta_csv(resposta, questao)
    end

    linha
  end

  # == Descrição
  # Método utilitário privado que analisa a estrutura interna de uma resposta e extrai seu conteúdo bruto de acordo com o tipo da questão.
  #
  # == Argumentos
  # * +resposta+: Objeto do modelo +Resposta+ (pode receber o valor +nil+ se o aluno deixou em branco).
  # * +questao+: Objeto do modelo +Questao+.
  #
  # == Retorno
  # * Retorna a String "Sem resposta" se a instância for nula.
  # * Retorna uma string contendo o texto limpo caso a questão seja discursiva.
  # * Retorna o texto da opção ou opções selecionadas (unidas por vírgula se for múltipla escolha) caso a questão seja objetiva.
  #
  # == Efeitos Colaterais
  # * Nenhum.
  def valor_resposta_csv(resposta, questao)
    return "Sem resposta" if resposta.nil?
    return resposta.texto&.texto.to_s.strip if questao.discursiva?

    resposta.opcoes_escolhidas.map { |opcao_escolhida| opcao_escolhida.opcao.texto }.join(", ")
  end
end
# frozen_string_literal: true

require "json"

# Controla telas de dashboard, pesquisa e ações administrativas ligadas ao SIGAA.
#
# Este controller reúne o painel do usuário, a busca global, a importação e
# sincronização de dados do SIGAA e o envio de convites para definição de senha.
class DashboardController < ApplicationController
  include BrevoEmailable
  before_action :verificar_usuario, only: %i[index pesquisar sugestoes]
  before_action :verificar_admin, only: %i[gerenciamento importar_dados enviar_solicitacoes]

  # Exibe o dashboard do usuário autenticado.
  #
  # Não recebe argumentos.
  #
  # @return [void]
  # @side_effect Consulta avaliações pendentes do usuário atual e atribui
  #   +@avaliacoes_pendentes+ para a view.
  def index
    @avaliacoes_pendentes = avaliacoes_do_usuario.limit(6)
  end

  # Executa a pesquisa global do dashboard.
  #
  # Não recebe argumentos diretamente; usa +params[:q]+, +params[:turma_id]+ e
  # filtros enviados pela requisição.
  #
  # @return [void]
  # @side_effect Inicializa variáveis de instância usadas pela view e preenche
  #   resultados de avaliações, templates ou formulários conforme o filtro.
  def pesquisar
    inicializar_pesquisa

    return if @termo.blank?
    return pesquisar_por_turma if params[:turma_id].present?

    pesquisar_por_termo
  end

  # Exibe a página administrativa de gerenciamento.
  #
  # Não recebe argumentos.
  #
  # @return [void]
  # @side_effect Renderiza a tela com ações de importação do SIGAA, envio de
  #   solicitações de cadastro e links administrativos.
  def gerenciamento
  end

  # Envia solicitações de definição de senha para usuários pendentes.
  #
  # Não recebe argumentos diretamente; usa o departamento do administrador
  # autenticado para filtrar docentes e discentes pendentes.
  #
  # @return [void]
  # @side_effect Cria tokens de cadastro, envia e-mails pela Brevo e redireciona
  #   para +gerenciamento_path+ com flash de sucesso, aviso ou erro parcial.
  def enviar_solicitacoes
    depto_id = current_user.perfil_adm&.departamento_id

    if depto_id.blank?
      redirect_to gerenciamento_path, flash: { error: "Seu usuário não possui um departamento associado." } and return
    end

    usuarios_pendentes = usuarios_pendentes_do_departamento(depto_id)

    if usuarios_pendentes.empty?
      redirect_to gerenciamento_path, flash: { notice: "Não há usuários pendentes de cadastro (docentes ou discentes) neste departamento." } and return
    end

    resultado = enviar_convites_pendentes(usuarios_pendentes)
    redirecionar_envio_solicitacoes(resultado[:sucessos], resultado[:erros_envio])
  end

  # Importa e sincroniza dados do SIGAA na base local.
  #
  # Não recebe argumentos diretamente; lê o arquivo retornado por
  # #caminho_arquivo_sigaa.
  #
  # @return [void]
  # @side_effect Lê JSON, cria ou atualiza matérias, turmas, usuários, perfis e
  #   participações, remove dados obsoletos e redireciona com flash de sucesso
  #   ou erro parcial.
  # @raise [JSON::ParserError] Quando o arquivo de entrada não contém JSON
  #   válido.
  def importar_dados
    caminho_arquivo = caminho_arquivo_sigaa
    unless File.exist?(caminho_arquivo)
      redirect_to gerenciamento_path, flash: { error: "Arquivo JSON não encontrado em db/" } and return
    end

    dados = JSON.parse(File.read(caminho_arquivo))
    contexto = contexto_importacao_sigaa

    importar_materias_sigaa(dados, contexto)
    importar_turmas_sigaa(dados, contexto)
    importar_docentes_sigaa(dados, contexto)
    importar_discentes_sigaa(dados, contexto)
    sincronizar_remocoes_sigaa(contexto)
    redirecionar_importacao_sigaa(contexto[:erros_importacao])
  end

  # Retorna sugestões de pesquisa em JSON.
  #
  # Não recebe argumentos diretamente; usa +params[:q]+ e filtros da requisição.
  #
  # @return [void]
  # @side_effect Renderiza uma resposta JSON com sugestões ou uma lista vazia.
  def sugestoes
    termo = params[:q].to_s.strip
    return render json: [] if termo.blank?

    render json: sugestoes_do_termo(termo)
  end

  private

  # Busca usuários pendentes pertencentes ao departamento informado.
  #
  # @param depto_id [Integer] Identificador do departamento do administrador.
  # @return [Array<Usuario>] Lista única de docentes e discentes pendentes.
  def usuarios_pendentes_do_departamento(depto_id)
    turmas_do_departamento_ids = Turma.joins(:materia).where(materias: { departamento_id: depto_id }).ids
    discentes_pendentes = Usuario.joins(:participacoes_turma)
                                 .where(status: 0, participacoes_turma: { turma_id: turmas_do_departamento_ids })
    docentes_pendentes = Usuario.joins(:perfil_docente)
                                .where(status: 0, perfis_docentes: { departamento_id: depto_id })

    (discentes_pendentes + docentes_pendentes).uniq
  end

  # Envia convites para uma coleção de usuários pendentes.
  #
  # @param usuarios_pendentes [Enumerable<Usuario>] Usuários que devem receber
  #   link de definição de senha.
  # @return [Hash] Resultado com chaves +:sucessos+ e +:erros_envio+.
  # @side_effect Pode criar tokens e enviar e-mails para cada usuário.
  def enviar_convites_pendentes(usuarios_pendentes)
    resultado = { sucessos: 0, erros_envio: [] }

    usuarios_pendentes.each do |usuario|
      resultado[:sucessos] += 1 if enviar_convite_pendente(usuario, resultado[:erros_envio])
    end

    resultado
  end

  # Envia um convite de cadastro para um usuário pendente.
  #
  # @param usuario [Usuario] Usuário que receberá o convite.
  # @param erros_envio [Array<String>] Lista mutável onde erros serão anexados.
  # @return [Boolean] +true+ quando o e-mail foi enviado; +false+ quando houve
  #   erro e a transação foi revertida.
  # @side_effect Cria Token em transação, chama a API de e-mail e pode adicionar
  #   mensagens em +erros_envio+.
  def enviar_convite_pendente(usuario, erros_envio)
    enviado = false

    ActiveRecord::Base.transaction do
      token_gerado = criar_token_cadastro!(usuario)

      if enviar_email_convite_admin(usuario.email, token_gerado, current_user.nome)
        enviado = true
      else
        raise "Falha de comunicação com a Brevo."
      end
    rescue StandardError => e
      erros_envio << "#{usuario.nome} (Matrícula: #{usuario.matricula}): #{e.message}"
      raise ActiveRecord::Rollback
    end

    enviado
  end

  # Cria um token temporário de cadastro para o usuário.
  #
  # @param usuario [Usuario] Usuário dono do token.
  # @return [String] Valor do token gerado.
  # @side_effect Persiste um registro de Token com validade de dez minutos.
  def criar_token_cadastro!(usuario)
    token_gerado = SecureRandom.hex(16)
    usuario.tokens.create!(
      value: token_gerado,
      tipo: "cadastro",
      expires_at: 10.minutes.from_now
    )
    token_gerado
  end

  # Redireciona após o envio de solicitações de cadastro.
  #
  # @param sucessos [Integer] Quantidade de e-mails enviados com sucesso.
  # @param erros_envio [Array<String>] Erros coletados durante os envios.
  # @return [void]
  # @side_effect Redireciona para +gerenciamento_path+ com flash de sucesso ou
  #   erro parcial.
  def redirecionar_envio_solicitacoes(sucessos, erros_envio)
    if erros_envio.empty?
      redirect_to gerenciamento_path, flash: { success: "Convites enviados com sucesso para os <strong>#{sucessos}</strong> usuários do departamento!" }
    else
      redirect_to gerenciamento_path, flash: {
        error: "O envio foi concluído com instabilidades. Foram enviados #{sucessos} e-mails.",
        error_list: erros_envio
      }
    end
  end

  # Informa o caminho do arquivo JSON usado como fonte SIGAA.
  #
  # Não recebe argumentos.
  #
  # @return [Pathname] Caminho para +db/usuarios_sigaa.json+.
  def caminho_arquivo_sigaa
    Rails.root.join("db", "usuarios_sigaa.json")
  end

  # Cria a estrutura de controle usada durante a importação SIGAA.
  #
  # Não recebe argumentos.
  #
  # @return [Hash] Hash com listas de matérias, turmas, matrículas ativas e
  #   erros de importação.
  def contexto_importacao_sigaa
    {
      codigos_materias_ativos: [],
      turmas_ativas_ids: [],
      matriculas_ativas_json: [],
      erros_importacao: []
    }
  end

  # Importa todas as matérias presentes no JSON do SIGAA.
  #
  # @param dados [Hash] Dados parseados do arquivo SIGAA.
  # @param contexto [Hash] Estrutura de controle da importação.
  # @return [void]
  # @side_effect Cria ou atualiza registros de Materia e acumula erros no
  #   contexto.
  def importar_materias_sigaa(dados, contexto)
    dados["materias"]&.each do |materia_json|
      importar_materia_sigaa(materia_json, contexto)
    end
  end

  # Importa uma matéria individual do SIGAA.
  #
  # @param materia_json [Hash] Dados da matéria, incluindo código, nome e
  #   departamento.
  # @param contexto [Hash] Estrutura de controle da importação.
  # @return [void]
  # @side_effect Persiste Materia, registra o código como ativo e adiciona erro
  #   ao contexto quando a importação falha.
  def importar_materia_sigaa(materia_json, contexto)
    codigo = materia_json["codigo"]

    ActiveRecord::Base.transaction do
      contexto[:codigos_materias_ativos] << codigo
      materia = Materia.find_or_initialize_by(codigo: codigo)
      materia.nome = materia_json["nome"]
      materia.departamento_id = materia_json["departamento_id_temp"]
      materia.save!
    end
  rescue StandardError => e
    contexto[:erros_importacao] << "Matéria #{materia_json['nome']} (Código: #{codigo}): #{e.message}"
  end

  # Importa todas as turmas presentes no JSON do SIGAA.
  #
  # @param dados [Hash] Dados parseados do arquivo SIGAA.
  # @param contexto [Hash] Estrutura de controle da importação.
  # @return [void]
  # @side_effect Cria ou atualiza registros de Turma e acumula erros no
  #   contexto.
  def importar_turmas_sigaa(dados, contexto)
    dados["turmas"]&.each do |turma_json|
      importar_turma_sigaa(turma_json, contexto)
    end
  end

  # Importa uma turma individual do SIGAA.
  #
  # @param turma_json [Hash] Dados da turma, incluindo número, ano, semestre e
  #   código da matéria.
  # @param contexto [Hash] Estrutura de controle da importação.
  # @return [void]
  # @side_effect Persiste Turma, registra seu ID como ativo e adiciona erro ao
  #   contexto quando a importação falha.
  def importar_turma_sigaa(turma_json, contexto)
    ActiveRecord::Base.transaction do
      materia = encontrar_materia_sigaa!(turma_json["materia_codigo"])
      turma = salvar_turma_sigaa!(turma_json, materia)
      contexto[:turmas_ativas_ids] << turma.id
    end
  rescue StandardError => e
    contexto[:erros_importacao] << "Turma nº #{turma_json['numero']} (#{turma_json['ano']}/#{turma_json['semestre']}) da matéria '#{turma_json['materia_codigo']}': #{e.message}"
  end

  # Cria ou atualiza uma turma a partir dos dados do SIGAA.
  #
  # @param turma_json [Hash] Dados da turma importada.
  # @param materia [Materia] Matéria associada à turma.
  # @return [Turma] Turma persistida.
  # @side_effect Altera ou cria registro de Turma no banco.
  # @raise [ActiveRecord::RecordInvalid] Quando a turma não passa nas
  #   validações.
  def salvar_turma_sigaa!(turma_json, materia)
    turma = Turma.find_or_initialize_by(
      numero: turma_json["numero"],
      ano: turma_json["ano"],
      semestre: turma_json["semestre"],
      materia_id: materia.id
    )
    turma.save!
    turma
  end

  # Importa todos os docentes presentes no JSON do SIGAA.
  #
  # @param dados [Hash] Dados parseados do arquivo SIGAA.
  # @param contexto [Hash] Estrutura de controle da importação.
  # @return [void]
  # @side_effect Cria ou atualiza usuários docentes, perfis docentes e
  #   participações em turmas.
  def importar_docentes_sigaa(dados, contexto)
    dados["usuarios_docentes"]&.each do |docente_json|
      importar_docente_sigaa(docente_json, contexto)
    end
  end

  # Importa um docente individual do SIGAA.
  #
  # @param docente_json [Hash] Dados do docente, incluindo matrícula, nome,
  #   e-mail, departamento e turmas lecionadas.
  # @param contexto [Hash] Estrutura de controle da importação.
  # @return [void]
  # @side_effect Persiste Usuario, PerfilDocente e ParticipacaoTurma, remove
  #   participações docentes antigas e registra erros no contexto.
  def importar_docente_sigaa(docente_json, contexto)
    matricula = docente_json["matricula"]

    ActiveRecord::Base.transaction do
      contexto[:matriculas_ativas_json] << matricula
      usuario = salvar_usuario_importado_sigaa!(docente_json, matricula)
      salvar_perfil_docente_sigaa!(usuario, docente_json)
      turmas_docente_ids = importar_participacoes_docente_sigaa!(usuario, docente_json)
      usuario.participacoes_turma.docentes.where.not(turma_id: turmas_docente_ids).destroy_all
    end
  rescue StandardError => e
    contexto[:erros_importacao] << "Docente #{docente_json['nome']} (Matrícula: #{matricula}): #{e.message}"
  end

  # Cria ou atualiza o perfil docente do usuário importado.
  #
  # @param usuario [Usuario] Usuário docente importado.
  # @param docente_json [Hash] Dados do docente vindos do SIGAA.
  # @return [void]
  # @side_effect Persiste PerfilDocente associado ao usuário.
  # @raise [ActiveRecord::RecordInvalid] Quando o perfil não passa nas
  #   validações.
  def salvar_perfil_docente_sigaa!(usuario, docente_json)
    perfil = PerfilDocente.find_or_initialize_by(id: usuario.id)
    perfil.departamento_id = docente_json["departamento_id_temp"]
    perfil.save!
  end

  # Importa as participações docentes nas turmas lecionadas.
  #
  # @param usuario [Usuario] Usuário docente importado.
  # @param docente_json [Hash] Dados do docente com a lista de turmas.
  # @return [Array<Integer>] IDs das turmas em que o docente permanece ativo.
  # @side_effect Cria participações docentes no banco.
  def importar_participacoes_docente_sigaa!(usuario, docente_json)
    turmas_docente_ids = []
    (docente_json["turmas_lecionadas"] || []).each do |mat_json|
      importar_participacao_sigaa!(usuario, mat_json, :docente, turmas_docente_ids)
    end
    turmas_docente_ids
  end

  # Importa todos os discentes presentes no JSON do SIGAA.
  #
  # @param dados [Hash] Dados parseados do arquivo SIGAA.
  # @param contexto [Hash] Estrutura de controle da importação.
  # @return [void]
  # @side_effect Cria ou atualiza usuários discentes, perfis discentes e
  #   matrículas em turmas.
  def importar_discentes_sigaa(dados, contexto)
    dados["usuarios_discentes"]&.each do |discente_json|
      importar_discente_sigaa(discente_json, contexto)
    end
  end

  # Importa um discente individual do SIGAA.
  #
  # @param discente_json [Hash] Dados do discente, incluindo matrícula, nome,
  #   e-mail e turmas matriculadas.
  # @param contexto [Hash] Estrutura de controle da importação.
  # @return [void]
  # @side_effect Persiste Usuario, PerfilDiscente e ParticipacaoTurma, remove
  #   matrículas antigas e registra erros no contexto.
  def importar_discente_sigaa(discente_json, contexto)
    matricula = discente_json["matricula"]

    ActiveRecord::Base.transaction do
      contexto[:matriculas_ativas_json] << matricula
      usuario = salvar_usuario_importado_sigaa!(discente_json, matricula)
      PerfilDiscente.find_or_create_by!(id: usuario.id)
      turmas_aluno_ids = importar_participacoes_discente_sigaa!(usuario, discente_json)
      usuario.participacoes_turma.where.not(turma_id: turmas_aluno_ids).destroy_all
    end
  rescue StandardError => e
    contexto[:erros_importacao] << "Discente #{discente_json['nome']} (Matrícula: #{matricula}): #{e.message}"
  end

  # Importa as participações discentes nas turmas matriculadas.
  #
  # @param usuario [Usuario] Usuário discente importado.
  # @param discente_json [Hash] Dados do discente com turmas matriculadas.
  # @return [Array<Integer>] IDs das turmas em que o discente permanece ativo.
  # @side_effect Cria participações discentes no banco.
  def importar_participacoes_discente_sigaa!(usuario, discente_json)
    turmas_aluno_ids = []
    discente_json["turmas_matriculadas"].each do |mat_json|
      importar_participacao_sigaa!(usuario, mat_json, :discente, turmas_aluno_ids)
    end
    turmas_aluno_ids
  end

  # Cria ou atualiza um usuário importado do SIGAA.
  #
  # @param usuario_json [Hash] Dados do usuário vindos do SIGAA.
  # @param matricula [String] Matrícula institucional usada como chave.
  # @return [Usuario] Usuário persistido.
  # @side_effect Altera ou cria registro de Usuario no banco.
  # @raise [ActiveRecord::RecordInvalid] Quando o usuário não passa nas
  #   validações.
  def salvar_usuario_importado_sigaa!(usuario_json, matricula)
    usuario = Usuario.find_or_initialize_by(matricula: matricula)
    usuario.nome = usuario_json["nome"]
    usuario.email = usuario_json["email"]
    inicializar_usuario_importado_sigaa(usuario)
    usuario.save!
    usuario
  end

  # Define estado inicial para usuário recém-importado.
  #
  # @param usuario [Usuario] Usuário novo ou existente.
  # @return [void]
  # @side_effect Para usuários novos, define status pendente e senha vazia.
  def inicializar_usuario_importado_sigaa(usuario)
    return unless usuario.new_record?

    usuario.status = 0
    usuario.senha = ""
  end

  # Importa uma participação de usuário em turma do SIGAA.
  #
  # @param usuario [Usuario] Usuário que será vinculado à turma.
  # @param mat_json [Hash] Dados da matrícula ou turma lecionada.
  # @param tipo_participacao [Symbol] Tipo da participação, como +:docente+ ou
  #   +:discente+.
  # @param turmas_ids [Array<Integer>] Lista mutável que recebe IDs ativos.
  # @return [ParticipacaoTurma] Participação encontrada ou criada.
  # @side_effect Cria ParticipacaoTurma e adiciona o ID da turma em
  #   +turmas_ids+.
  # @raise [RuntimeError] Quando a matéria ou turma não é encontrada.
  def importar_participacao_sigaa!(usuario, mat_json, tipo_participacao, turmas_ids)
    turma = encontrar_turma_sigaa!(mat_json)
    turmas_ids << turma.id
    ParticipacaoTurma.find_or_create_by!(
      usuario_id: usuario.id,
      turma_id: turma.id,
      tipo_participacao: tipo_participacao
    )
  end

  # Encontra uma matéria pelo código importado do SIGAA.
  #
  # @param codigo [String] Código institucional da matéria.
  # @return [Materia] Matéria encontrada.
  # @raise [RuntimeError] Quando não existe matéria com o código informado.
  def encontrar_materia_sigaa!(codigo)
    materia = Materia.find_by(codigo: codigo)
    raise "Matéria com código '#{codigo}' não existe no sistema." if materia.nil?

    materia
  end

  # Encontra uma turma a partir dos dados de matrícula do SIGAA.
  #
  # @param mat_json [Hash] Dados com código da matéria, número da turma, ano e
  #   semestre.
  # @return [Turma] Turma encontrada.
  # @raise [RuntimeError] Quando a matéria ou turma não é encontrada.
  def encontrar_turma_sigaa!(mat_json)
    materia = encontrar_materia_sigaa!(mat_json["materia_codigo"])
    turma = Turma.find_by(
      materia_id: materia.id,
      numero: mat_json["numero_turma"],
      ano: mat_json["ano"],
      semestre: mat_json["semestre"]
    )
    if turma.nil?
      raise "Turma nº #{mat_json['numero_turma']} (#{mat_json['ano']}/#{mat_json['semestre']}) da matéria '#{materia.nome}' não foi localizada no sistema."
    end

    turma
  end

  # Remove dados locais que não aparecem mais na carga SIGAA atual.
  #
  # @param contexto [Hash] Estrutura com códigos, IDs e matrículas ativos.
  # @return [void]
  # @side_effect Remove turmas, matérias e usuários obsoletos em transação.
  def sincronizar_remocoes_sigaa(contexto)
    ActiveRecord::Base.transaction do
      Turma.where.not(id: contexto[:turmas_ativas_ids]).destroy_all
      Materia.where.not(codigo: contexto[:codigos_materias_ativos]).destroy_all
      remover_usuarios_importacao_sigaa(contexto[:matriculas_ativas_json])
    end
  end

  # Remove usuários não administrativos ausentes na importação atual.
  #
  # @param matriculas_ativas_json [Array<String>] Matrículas presentes no JSON
  #   importado.
  # @return [void]
  # @side_effect Destrói usuários que não estão na lista e não são
  #   administradores.
  def remover_usuarios_importacao_sigaa(matriculas_ativas_json)
    Usuario.where.not(matricula: matriculas_ativas_json).each do |usuario|
      next if usuario.administrador?

      usuario.destroy!
    end
  end

  # Redireciona ao final da importação SIGAA.
  #
  # @param erros_importacao [Array<String>] Erros coletados durante a
  #   importação.
  # @return [void]
  # @side_effect Redireciona para +gerenciamento_path+ com flash de sucesso ou
  #   erro parcial.
  def redirecionar_importacao_sigaa(erros_importacao)
    if erros_importacao.empty?
      redirect_to gerenciamento_path, flash: { success: "Dados do SIGAA importados e sincronizados com sucesso!" }
    else
      redirect_to gerenciamento_path, flash: { error: "A importação foi concluída parcialmente.", error_list: erros_importacao }
    end
  end

  # Inicializa variáveis usadas pela busca global.
  #
  # Não recebe argumentos diretamente; usa parâmetros da requisição.
  #
  # @return [void]
  # @side_effect Define +@termo+, coleções vazias e tipos selecionados para a
  #   view de pesquisa.
  def inicializar_pesquisa
    @termo = params[:q].to_s.strip
    @avaliacoes = Avaliacao.none
    @templates = Template.none
    @formularios = Formulario.none
    @tipos_selecionados = tipos_selecionados
  end

  # Pesquisa resultados vinculados a uma turma específica.
  #
  # Não recebe argumentos diretamente; usa +params[:turma_id]+.
  #
  # @return [void]
  # @side_effect Atribui +@avaliacoes+ e, para administradores, +@formularios+.
  def pesquisar_por_turma
    turma_id = params[:turma_id]
    @avaliacoes = avaliacoes_da_turma(turma_id) if tipo_selecionado?("avaliacoes")
    @formularios = formularios_da_turma(turma_id) if administrador_com_tipo?("formularios")
  end

  # Pesquisa resultados textuais pelo termo informado.
  #
  # Não recebe argumentos diretamente; usa +@termo+ e os filtros selecionados.
  #
  # @return [void]
  # @side_effect Atribui coleções de avaliações, templates e formulários para a
  #   view conforme permissões e filtros.
  def pesquisar_por_termo
    padrao = padrao_pesquisa
    @avaliacoes = pesquisar_avaliacoes(padrao) if tipo_selecionado?("avaliacoes")

    return unless current_user.administrador?

    @templates = pesquisar_templates(padrao) if tipo_selecionado?("templates")
    @formularios = pesquisar_formularios(padrao) if tipo_selecionado?("formularios")
  end

  # Monta o padrão SQL seguro para busca textual.
  #
  # Não recebe argumentos; usa +@termo+.
  #
  # @return [String] Termo sanitizado envolvido por porcentagens para uso com
  #   +LIKE+.
  def padrao_pesquisa
    "%#{ActiveRecord::Base.sanitize_sql_like(@termo.downcase)}%"
  end

  # Verifica se um tipo de resultado está selecionado.
  #
  # @param tipo [String] Tipo de resultado, como "avaliacoes", "templates" ou
  #   "formularios".
  # @return [Boolean] +true+ quando o tipo está presente em
  #   +@tipos_selecionados+.
  def tipo_selecionado?(tipo)
    @tipos_selecionados.include?(tipo)
  end

  # Verifica se o usuário é administrador e selecionou um tipo.
  #
  # @param tipo [String] Tipo de resultado administrativo.
  # @return [Boolean] +true+ quando o usuário atual é administrador e o tipo
  #   está selecionado.
  def administrador_com_tipo?(tipo)
    current_user.administrador? && tipo_selecionado?(tipo)
  end

  # Monta todas as sugestões disponíveis para um termo.
  #
  # @param termo [String] Texto digitado pelo usuário.
  # @return [Array<Hash>] Lista de sugestões básicas, avaliações e resultados
  #   administrativos permitidos.
  def sugestoes_do_termo(termo)
    tipos = tipos_selecionados
    padrao = "%#{ActiveRecord::Base.sanitize_sql_like(termo.downcase)}%"

    sugestoes_basicas(termo, padrao, tipos) +
      sugestoes_avaliacoes(padrao, tipos) +
      sugestoes_administrador(padrao, tipos)
  end

  # Monta sugestões básicas de turmas e matérias.
  #
  # @param termo [String] Texto original digitado pelo usuário.
  # @param padrao [String] Padrão sanitizado para consultas com +LIKE+.
  # @param tipos [Array<String>] Tipos de resultado selecionados.
  # @return [Array<Hash>] Sugestões de turmas e matérias.
  def sugestoes_basicas(termo, padrao, tipos)
    sugestoes_turmas(termo, tipos) + sugestoes_materias(padrao, tipos)
  end

  # Monta sugestões de turmas compatíveis com o termo.
  #
  # @param termo [String] Texto original digitado pelo usuário.
  # @param tipos [Array<String>] Tipos de resultado selecionados.
  # @return [Array<Hash>] Até três sugestões de turmas.
  def sugestoes_turmas(termo, tipos)
    pesquisar_turmas(termo).limit(3).map do |turma|
      {
        tipo: "Turma",
        titulo: turma.materia.nome,
        subtitulo: nil,
        materia_codigo: turma.materia.codigo,
        turma_codigo: turma.codigo_exibicao,
        url: turma_suggestion_url(turma, tipos)
      }
    end
  end

  # Monta sugestões de matérias compatíveis com o padrão de busca.
  #
  # @param padrao [String] Padrão sanitizado para consultas com +LIKE+.
  # @param tipos [Array<String>] Tipos de resultado selecionados.
  # @return [Array<Hash>] Até três sugestões de matérias.
  def sugestoes_materias(padrao, tipos)
    pesquisar_materias(padrao).limit(3).map do |materia|
      {
        tipo: "Matéria",
        titulo: materia.nome,
        subtitulo: nil,
        materia_codigo: materia.codigo,
        url: materia_suggestion_url(materia, tipos)
      }
    end
  end

  # Monta sugestões de avaliações pendentes.
  #
  # @param padrao [String] Padrão sanitizado para consultas com +LIKE+.
  # @param tipos [Array<String>] Tipos de resultado selecionados.
  # @return [Array<Hash>] Sugestões de avaliações ou lista vazia quando o tipo
  #   não está selecionado.
  def sugestoes_avaliacoes(padrao, tipos)
    return [] unless tipos.include?("avaliacoes")

    pesquisar_avaliacoes(padrao).limit(5).map do |avaliacao|
      sugestao_avaliacao(avaliacao)
    end
  end

  # Monta o hash de sugestão para uma avaliação.
  #
  # @param avaliacao [Avaliacao] Avaliação pendente que será sugerida.
  # @return [Hash] Dados exibidos no autocomplete da pesquisa.
  def sugestao_avaliacao(avaliacao)
    turma = avaliacao.formulario.turma

    {
      tipo: "Avaliação",
      titulo: avaliacao.formulario.template&.titulo || "Avaliação",
      subtitulo: turma.nome_exibicao,
      materia_codigo: turma.materia.codigo,
      turma_codigo: turma.codigo_exibicao,
      url: responder_avaliacao_path(avaliacao)
    }
  end

  # Monta sugestões visíveis apenas para administradores.
  #
  # @param padrao [String] Padrão sanitizado para consultas com +LIKE+.
  # @param tipos [Array<String>] Tipos de resultado selecionados.
  # @return [Array<Hash>] Sugestões de templates e formulários ou lista vazia
  #   para usuários não administradores.
  def sugestoes_administrador(padrao, tipos)
    return [] unless current_user.administrador?

    sugestoes_templates(padrao, tipos) + sugestoes_formularios(padrao, tipos)
  end

  # Monta sugestões de templates.
  #
  # @param padrao [String] Padrão sanitizado para consultas com +LIKE+.
  # @param tipos [Array<String>] Tipos de resultado selecionados.
  # @return [Array<Hash>] Sugestões de templates ou lista vazia quando o tipo
  #   não está selecionado.
  def sugestoes_templates(padrao, tipos)
    return [] unless tipos.include?("templates")

    pesquisar_templates(padrao).limit(5).map do |template|
      {
        tipo: "Template",
        titulo: template.titulo,
        subtitulo: template.descricao.presence || "Sem descrição",
        url: template_path(template)
      }
    end
  end

  # Monta sugestões de formulários.
  #
  # @param padrao [String] Padrão sanitizado para consultas com +LIKE+.
  # @param tipos [Array<String>] Tipos de resultado selecionados.
  # @return [Array<Hash>] Sugestões de formulários ou lista vazia quando o tipo
  #   não está selecionado.
  def sugestoes_formularios(padrao, tipos)
    return [] unless tipos.include?("formularios")

    pesquisar_formularios(padrao).limit(5).map do |formulario|
      {
        tipo: "Formulário",
        titulo: formulario.template&.titulo || "Template removido",
        subtitulo: formulario.turma.nome_exibicao,
        materia_codigo: formulario.turma.materia.codigo,
        turma_codigo: formulario.turma.codigo_exibicao,
        url: formulario_path(formulario)
      }
    end
  end

  # Define os tipos de resultado selecionados na busca.
  #
  # Não recebe argumentos diretamente; usa +params[:filtro_ativo]+,
  # +params[:tipos]+ e +params[:sem_templates]+.
  #
  # Sem o filtro aberto, assume as três categorias. Com o filtro aberto, usa
  # exatamente o que está marcado. +sem_templates+ força a exclusão mesmo que
  # "templates" venha marcado por algum motivo.
  #
  # @return [Array<String>] Tipos selecionados para pesquisa e sugestões.
  def tipos_selecionados
    tipos = if params[:filtro_ativo].present?
              Array(params[:tipos])
    else
              %w[avaliacoes templates formularios]
    end

    tipos -= [ "templates" ] if params[:sem_templates] == "1"
    tipos
  end

  # Garante que exista usuário autenticado.
  #
  # Não recebe argumentos.
  #
  # @return [void]
  # @side_effect Redireciona para a página inicial com flash de erro quando não
  #   há usuário logado.
  def verificar_usuario
    return if current_user.present?

    redirect_to root_path,
      flash: { error: "Acesso restrito. Por favor, faça login para continuar." }
  end

  # Busca avaliações pendentes do usuário atual.
  #
  # Não recebe argumentos.
  #
  # @return [ActiveRecord::Relation<Avaliacao>] Relação de avaliações pendentes
  #   ordenadas da mais recente para a mais antiga.
  def avaliacoes_do_usuario
    Avaliacao
      .pendentes
      .joins(:participacao_turma)
      .where(participacoes_turmas: { usuario_id: current_user.id })
      .includes(formulario: [ :template, { turma: :materia } ])
      .order(created_at: :desc)
  end

  # Busca avaliações pendentes do usuário para uma turma.
  #
  # @param turma_id [Integer, String] Identificador da turma filtrada.
  # @return [ActiveRecord::Relation<Avaliacao>] Relação de avaliações da turma.
  def avaliacoes_da_turma(turma_id)
    avaliacoes_do_usuario
      .joins(:formulario)
      .where(formularios: { turma_id: turma_id })
  end

  # Busca formulários de uma turma no departamento do administrador.
  #
  # @param turma_id [Integer, String] Identificador da turma filtrada.
  # @return [ActiveRecord::Relation<Formulario>] Relação de formulários
  #   recentes da turma.
  def formularios_da_turma(turma_id)
    Formulario
      .do_departamento(current_administrador.departamento)
      .where(turma_id: turma_id)
      .includes(:template, turma: :materia)
      .recentes
  end

  # Pesquisa avaliações pendentes por título, matéria ou código.
  #
  # @param padrao [String] Padrão sanitizado para consultas com +LIKE+.
  # @return [ActiveRecord::Relation<Avaliacao>] Avaliações compatíveis com o
  #   padrão.
  def pesquisar_avaliacoes(padrao)
    avaliacoes_do_usuario
      .joins(formulario: [ :template, { turma: :materia } ])
      .where(
        "LOWER(templates.titulo) LIKE :padrao OR LOWER(materias.nome) LIKE :padrao OR LOWER(materias.codigo) LIKE :padrao",
        padrao: padrao
      )
  end

  # Pesquisa templates pelo título ou descrição.
  #
  # @param padrao [String] Padrão sanitizado para consultas com +LIKE+.
  # @return [ActiveRecord::Relation<Template>] Templates permitidos pela policy
  #   e compatíveis com o padrão.
  def pesquisar_templates(padrao)
    policy_scope(Template)
      .where(
        "LOWER(templates.titulo) LIKE :padrao OR " \
          "LOWER(COALESCE(templates.descricao, '')) LIKE :padrao",
        padrao: padrao
      )
      .recentes
  end

  # Pesquisa formulários por template, matéria ou código.
  #
  # @param padrao [String] Padrão sanitizado para consultas com +LIKE+.
  # @return [ActiveRecord::Relation<Formulario>] Formulários do departamento do
  #   administrador compatíveis com o padrão.
  def pesquisar_formularios(padrao)
    Formulario
      .do_departamento(current_administrador.departamento)
      .joins(:template, turma: :materia)
      .where(
        "LOWER(templates.titulo) LIKE :padrao OR LOWER(materias.nome) LIKE :padrao OR LOWER(materias.codigo) LIKE :padrao",
        padrao: padrao
      )
      .includes(:template, turma: :materia)
      .recentes
  end

  # Pesquisa matérias por nome ou código.
  #
  # @param padrao [String] Padrão sanitizado para consultas com +LIKE+.
  # @return [ActiveRecord::Relation<Materia>] Matérias compatíveis ordenadas por
  #   nome.
  def pesquisar_materias(padrao)
    Materia.where(
      "LOWER(nome) LIKE :padrao OR LOWER(codigo) LIKE :padrao",
      padrao: padrao
    ).order(:nome)
  end

  # Pesquisa turmas quando o termo contém matéria e identificador da turma.
  #
  # @param termo [String] Texto com nome/código da matéria e turma, como
  #   "CIC0001 A" ou "Estruturas de Dados 1".
  # @return [ActiveRecord::Relation<Turma>] Turmas compatíveis ou relação vazia
  #   quando o termo não segue o formato esperado.
  def pesquisar_turmas(termo)
    match = termo.match(/\A(.+?)\s+([A-Za-z]|\d{1,2})\z/)
    return Turma.none unless match

    materia_termo = match[1].strip
    return Turma.none if materia_termo.blank?

    numero = Turma.numero_de_codigo_exibicao(match[2])
    padrao_materia = "%#{ActiveRecord::Base.sanitize_sql_like(materia_termo.downcase)}%"

    Turma
      .joins(:materia)
      .includes(:materia)
      .where(numero: numero)
      .where(
        "LOWER(materias.nome) LIKE :padrao OR LOWER(materias.codigo) LIKE :padrao",
        padrao: padrao_materia
      )
      .order(:numero)
  end

  # Monta URL de pesquisa para sugestão de matéria.
  #
  # @param materia [Materia] Matéria selecionada na sugestão.
  # @param tipos [Array<String>] Tipos selecionados antes da navegação.
  # @return [String] URL para a página de pesquisa com templates excluídos.
  #
  # Matéria não tem relação com templates, então a navegação remove "templates"
  # da lista de tipos e marca +sem_templates=1+ para a topbar desabilitar esse
  # checkbox.
  def materia_suggestion_url(materia, tipos)
    tipos_aplicaveis = tipos - [ "templates" ]
    tipos_aplicaveis = %w[avaliacoes formularios] if tipos_aplicaveis.empty?

    pesquisa_path(q: materia.nome, filtro_ativo: "1", tipos: tipos_aplicaveis, sem_templates: "1")
  end

  # Monta URL de pesquisa para sugestão de turma.
  #
  # @param turma [Turma] Turma selecionada na sugestão.
  # @param tipos [Array<String>] Tipos selecionados antes da navegação.
  # @return [String] URL para a página de pesquisa filtrada pela turma, com
  #   templates excluídos.
  def turma_suggestion_url(turma, tipos)
    tipos_aplicaveis = tipos - [ "templates" ]
    tipos_aplicaveis = %w[avaliacoes formularios] if tipos_aplicaveis.empty?

    pesquisa_path(
      q: turma.nome_exibicao,
      filtro_ativo: "1",
      tipos: tipos_aplicaveis,
      sem_templates: "1",
      turma_id: turma.id
    )
  end

  # Garante que o usuário atual seja administrador.
  #
  # Não recebe argumentos.
  #
  # @return [void]
  # @side_effect Limpa a sessão, remove o cache de usuário atual e redireciona
  #   para a página inicial quando o usuário não é administrador.
  def verificar_admin
    if current_user.nil? || !current_user.administrador?
      session.clear
      @current_user = nil
      redirect_to root_path, flash: { error: "Acesso restrito. Por favor, faça login como administrador." }
    end
  end
end

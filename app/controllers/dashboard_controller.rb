# frozen_string_literal: true

require "json"

# Controlador responsável pelo painel principal do sistema: exibição das
# avaliações pendentes na tela inicial, pesquisa e sugestões de busca
# (turmas, matérias, avaliações, templates e formulários), e pela área de
# gerenciamento restrita a administradores (envio de convites de cadastro
# e importação/sincronização de dados a partir do arquivo do SIGAA).
class DashboardController < ApplicationController
  include BrevoEmailable
  before_action :verificar_usuario, only: %i[index pesquisar sugestoes]
  before_action :verificar_admin, only: %i[gerenciamento importar_dados enviar_solicitacoes]

  # == Descrição
  # Exibe a tela inicial do sistema, listando um resumo das avaliações
  # pendentes do usuário autenticado.
  #
  # == Argumentos
  # * Nenhum. Consome indiretamente o +current_user+ da sessão.
  #
  # == Retorno
  # * Renderiza a view +index+.
  # * Popula a variável de instância +@avaliacoes_pendentes+ (limitada a
  #   6 registros).
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura.
  # * *Redirecionamento*: bloqueia e redireciona caso o usuário não esteja
  #   autenticado (via +before_action :verificar_usuario+).
  def index
    @avaliacoes_pendentes = avaliacoes_do_usuario.limit(6)
  end

  # == Descrição
  # Processa a pesquisa disparada pela barra de busca, delegando para o
  # fluxo de pesquisa por turma (quando +turma_id+ é informado) ou por
  # termo livre.
  #
  # == Argumentos
  # * Consome +params[:q]+ (termo pesquisado), +params[:turma_id]+
  #   (opcional) e os parâmetros de filtro processados por
  #   +inicializar_pesquisa+.
  #
  # == Retorno
  # * Renderiza a view +pesquisar+ (implicitamente).
  # * Popula as variáveis de instância +@termo+, +@avaliacoes+,
  #   +@templates+, +@formularios+ e +@tipos_selecionados+.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, delegada a
  #   +pesquisar_por_turma+/+pesquisar_por_termo+.
  # * *Redirecionamento*: bloqueia e redireciona caso o usuário não esteja
  #   autenticado (via +before_action+). Interrompe a execução (sem
  #   pesquisar) caso o termo esteja em branco.
  def pesquisar
    inicializar_pesquisa

    return if @termo.blank?
    return pesquisar_por_turma if params[:turma_id].present?

    pesquisar_por_termo
  end

  # == Descrição
  # Exibe a tela de gerenciamento, restrita a administradores.
  #
  # == Argumentos
  # * Nenhum.
  #
  # == Retorno
  # * Renderiza a view +gerenciamento+.
  #
  # == Efeitos Colaterais
  # * *Redirecionamento*: bloqueia e redireciona (limpando a sessão)
  #   caso o usuário não esteja autenticado ou não seja administrador
  #   (via +before_action :verificar_admin+).
  def gerenciamento
  end

  # == Descrição
  # Dispara o envio de e-mails de convite de cadastro para todos os
  # usuários (docentes e discentes) pendentes de ativação no departamento
  # do administrador autenticado.
  #
  # == Argumentos
  # * Nenhum diretamente. Consome +current_user.perfil_adm.departamento_id+.
  #
  # == Retorno
  # * Sempre redireciona para +gerenciamento_path+. Possui múltiplos
  #   caminhos possíveis: departamento não associado, nenhum usuário
  #   pendente, ou resultado (sucesso total/parcial) do envio dos
  #   convites.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: leitura dos usuários pendentes; escrita
  #   (criação de tokens de cadastro) delegada a
  #   +enviar_convites_pendentes+.
  # * *Rede*: dispara chamadas HTTP à API da Brevo (via
  #   +enviar_convites_pendentes+) para cada usuário pendente.
  # * *Redirecionamento*: sempre redireciona para +gerenciamento_path+
  #   com uma mensagem flash (sucesso, aviso ou erro) refletindo o
  #   resultado.
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

  # == Descrição
  # Importa e sincroniza os dados institucionais (matérias, turmas,
  # docentes e discentes) a partir do arquivo JSON exportado do SIGAA,
  # criando/atualizando os registros correspondentes e removendo os que
  # não constam mais no arquivo.
  #
  # == Argumentos
  # * Nenhum diretamente. Lê o arquivo indicado por
  #   +caminho_arquivo_sigaa+ (+db/usuarios_sigaa.json+).
  #
  # == Retorno
  # * Sempre redireciona para +gerenciamento_path+. Possui múltiplos
  #   caminhos possíveis: arquivo não encontrado, ou resultado
  #   (sucesso total/parcial) da importação.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: cria/atualiza/remove registros de
  #   Materia, Turma, Usuario, PerfilDocente, PerfilDiscente e
  #   ParticipacaoTurma, delegado às operações de importação e ao
  #   método +sincronizar_remocoes_sigaa+.
  # * *Sistema de Arquivos*: realiza a leitura do arquivo JSON de
  #   importação.
  # * *Redirecionamento*: sempre redireciona para +gerenciamento_path+
  #   com uma mensagem flash refletindo o resultado.
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

  # == Descrição
  # Endpoint utilizado pela barra de busca para retornar, em formato
  # JSON, sugestões de resultados (turmas, matérias, avaliações,
  # templates e formulários) de acordo com o termo digitado.
  #
  # == Argumentos
  # * Consome +params[:q]+ (termo pesquisado) e os parâmetros de filtro
  #   processados por +tipos_selecionados+.
  #
  # == Retorno
  # * Renderiza uma resposta JSON: um array vazio caso o termo esteja em
  #   branco, ou o array de sugestões retornado por
  #   +sugestoes_do_termo+.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura.
  # * *Redirecionamento*: bloqueia e redireciona caso o usuário não
  #   esteja autenticado (via +before_action+).
  def sugestoes
    termo = params[:q].to_s.strip
    return render json: [] if termo.blank?

    render json: sugestoes_do_termo(termo)
  end

  private

  # == Descrição
  # Busca todos os usuários (docentes e discentes) com cadastro
  # pendente (+status: 0+) vinculados ao departamento informado, seja
  # por participação em turma (discentes) ou por perfil docente.
  #
  # == Argumentos
  # * +depto_id+ - ID do Departamento cujos usuários pendentes serão
  #   buscados.
  #
  # == Retorno
  # * Retorna um Array de Usuario (união, sem duplicatas, dos discentes
  #   e docentes pendentes encontrados).
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura (SELECT).
  def usuarios_pendentes_do_departamento(depto_id)
    turmas_do_departamento_ids = Turma.joins(:materia).where(materias: { departamento_id: depto_id }).ids
    discentes_pendentes = Usuario.joins(:participacoes_turma)
                                 .where(status: 0, participacoes_turma: { turma_id: turmas_do_departamento_ids })
    docentes_pendentes = Usuario.joins(:perfil_docente)
                                .where(status: 0, perfis_docentes: { departamento_id: depto_id })

    (discentes_pendentes + docentes_pendentes).uniq
  end

  # == Descrição
  # Itera sobre a lista de usuários pendentes, disparando o envio do
  # convite de cadastro para cada um e contabilizando sucessos e erros.
  #
  # == Argumentos
  # * +usuarios_pendentes+ - Array/Enumerable de Usuario para os quais o
  #   convite será enviado.
  #
  # == Retorno
  # * Retorna um Hash com as chaves +:sucessos+ (Integer, contagem de
  #   envios bem-sucedidos) e +:erros_envio+ (Array de String, uma
  #   mensagem por usuário que falhou).
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)* e *Rede*: delegados a
  #   +enviar_convite_pendente+, chamado uma vez para cada usuário.
  def enviar_convites_pendentes(usuarios_pendentes)
    resultado = { sucessos: 0, erros_envio: [] }

    usuarios_pendentes.each do |usuario|
      resultado[:sucessos] += 1 if enviar_convite_pendente(usuario, resultado[:erros_envio])
    end

    resultado
  end

  # == Descrição
  # Gera o token de cadastro e envia o e-mail de convite para um único
  # usuário, dentro de uma transação que é desfeita (rollback) caso o
  # envio falhe, evitando tokens "órfãos" no banco.
  #
  # == Argumentos
  # * +usuario+ - instância de Usuario que receberá o convite.
  # * +erros_envio+ - Array de String no qual a mensagem de erro será
  #   adicionada (por referência) caso o envio falhe.
  #
  # == Retorno
  # * Retorna +true+ se o e-mail foi enviado com sucesso, +false+ caso
  #   contrário.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: cria um registro de Token (via
  #   +criar_token_cadastro!+); o registro é revertido
  #   (+ActiveRecord::Rollback+) caso o envio do e-mail falhe.
  # * *Rede*: dispara uma chamada HTTP à API da Brevo (via
  #   +enviar_email_convite_admin+, do concern +BrevoEmailable+).
  # * *Array externo*: adiciona uma mensagem de erro a +erros_envio+ em
  #   caso de falha.
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

  # == Descrição
  # Gera e persiste um token de cadastro para o usuário informado, com
  # validade de 10 minutos.
  #
  # == Argumentos
  # * +usuario+ - instância de Usuario para a qual o token será criado.
  #
  # == Retorno
  # * Retorna uma String com o valor (hexadecimal) do token gerado.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: cria um novo registro de Token
  #   associado ao usuário (+usuario.tokens.create!+).
  def criar_token_cadastro!(usuario)
    token_gerado = SecureRandom.hex(16)
    usuario.tokens.create!(
      value: token_gerado,
      tipo: "cadastro",
      expires_at: 10.minutes.from_now
    )
    token_gerado
  end

  # == Descrição
  # Redireciona para a tela de gerenciamento com a mensagem flash
  # apropriada ao resultado do envio de convites (sucesso total ou
  # parcial).
  #
  # == Argumentos
  # * +sucessos+ - Integer com a quantidade de convites enviados com
  #   sucesso.
  # * +erros_envio+ - Array de String com as mensagens de erro dos
  #   convites que falharam.
  #
  # == Retorno
  # * Retorna o resultado de +redirect_to+. Possui duas mensagens
  #   possíveis, de acordo com a presença de erros.
  #
  # == Efeitos Colaterais
  # * *Redirecionamento*: redireciona para +gerenciamento_path+ com
  #   flash de sucesso (sem erros) ou de erro (incluindo
  #   +error_list+, quando há falhas).
  def redirecionar_envio_solicitacoes(sucessos, erros_envio)
    if erros_envio.empty?
      redirect_to gerenciamento_path, flash: { success: "Convites enviados com sucesso para os <strong>#{sucessos}</strong> usuários pendentes do departamento!" }
    else
      redirect_to gerenciamento_path, flash: {
        error: "O envio foi concluído com instabilidades. Foram enviados #{sucessos} e-mails.",
        error_list: erros_envio
      }
    end
  end

  # == Descrição
  # Retorna o caminho absoluto do arquivo JSON contendo os dados
  # exportados do SIGAA a serem importados.
  #
  # == Argumentos
  # * Nenhum.
  #
  # == Retorno
  # * Retorna um +Pathname+ apontando para +db/usuarios_sigaa.json+.
  #
  # == Efeitos Colaterais
  # * Nenhum.
  def caminho_arquivo_sigaa
    Rails.root.join("db", "usuarios_sigaa.json")
  end

  # == Descrição
  # Constrói a estrutura de acumuladores utilizada ao longo de todo o
  # fluxo de importação do SIGAA, para rastrear quais registros
  # permaneceram ativos (e assim não devem ser removidos na etapa de
  # sincronização) e quais erros ocorreram.
  #
  # == Argumentos
  # * Nenhum.
  #
  # == Retorno
  # * Retorna um Hash com as chaves +:codigos_materias_ativos+,
  #   +:turmas_ativas_ids+, +:matriculas_ativas_json+ e
  #   +:erros_importacao+, todas inicializadas como Arrays vazios.
  #
  # == Efeitos Colaterais
  # * Nenhum.
  def contexto_importacao_sigaa
    {
      codigos_materias_ativos: [],
      turmas_ativas_ids: [],
      matriculas_ativas_json: [],
      erros_importacao: []
    }
  end

  # == Descrição
  # Itera sobre a lista de matérias do JSON de importação, delegando a
  # criação/atualização de cada uma a +importar_materia_sigaa+.
  #
  # == Argumentos
  # * +dados+ - Hash com os dados completos do JSON de importação
  #   (utiliza a chave +"materias"+).
  # * +contexto+ - Hash de acumuladores (ver +contexto_importacao_sigaa+),
  #   atualizado por referência.
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: delegado a +importar_materia_sigaa+,
  #   chamado uma vez para cada matéria.
  def importar_materias_sigaa(dados, contexto)
    dados["materias"]&.each do |materia_json|
      importar_materia_sigaa(materia_json, contexto)
    end
  end

  # == Descrição
  # Cria ou atualiza uma Materia a partir dos dados informados,
  # registrando seu código como ativo no contexto de importação.
  #
  # == Argumentos
  # * +materia_json+ - Hash com os dados da matéria, contendo (ao menos)
  #   as chaves +"codigo"+, +"nome"+ e +"departamento_id_temp"+.
  # * +contexto+ - Hash de acumuladores, atualizado por referência (o
  #   código da matéria é adicionado a +:codigos_materias_ativos+, e uma
  #   eventual mensagem de erro é adicionada a +:erros_importacao+).
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: cria/atualiza um registro de Materia
  #   dentro de uma transação (+materia.save!+). Em caso de exceção, a
  #   transação é revertida e uma mensagem de erro é registrada em
  #   +contexto[:erros_importacao]+ (a exceção não é propagada).
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

  # == Descrição
  # Itera sobre a lista de turmas do JSON de importação, delegando a
  # criação/atualização de cada uma a +importar_turma_sigaa+.
  #
  # == Argumentos
  # * +dados+ - Hash com os dados completos do JSON de importação
  #   (utiliza a chave +"turmas"+).
  # * +contexto+ - Hash de acumuladores, atualizado por referência.
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: delegado a +importar_turma_sigaa+,
  #   chamado uma vez para cada turma.
  def importar_turmas_sigaa(dados, contexto)
    dados["turmas"]&.each do |turma_json|
      importar_turma_sigaa(turma_json, contexto)
    end
  end

  # == Descrição
  # Localiza a Materia correspondente e cria/atualiza a Turma a partir
  # dos dados informados, registrando seu ID como ativo no contexto de
  # importação.
  #
  # == Argumentos
  # * +turma_json+ - Hash com os dados da turma, contendo (ao menos) as
  #   chaves +"materia_codigo"+, +"numero"+, +"ano"+ e +"semestre"+.
  # * +contexto+ - Hash de acumuladores, atualizado por referência (o ID
  #   da turma é adicionado a +:turmas_ativas_ids+, e uma eventual
  #   mensagem de erro é adicionada a +:erros_importacao+).
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: leitura da Materia (via
  #   +encontrar_materia_sigaa!+) e escrita da Turma (via
  #   +salvar_turma_sigaa!+), dentro de uma transação. Em caso de
  #   exceção (matéria não encontrada ou falha de validação), a
  #   transação é revertida e uma mensagem de erro é registrada em
  #   +contexto[:erros_importacao]+ (a exceção não é propagada).
  def importar_turma_sigaa(turma_json, contexto)
    ActiveRecord::Base.transaction do
      materia = encontrar_materia_sigaa!(turma_json["materia_codigo"])
      turma = salvar_turma_sigaa!(turma_json, materia)
      contexto[:turmas_ativas_ids] << turma.id
    end
  rescue StandardError => e
    contexto[:erros_importacao] << "Turma nº #{turma_json['numero']} (#{turma_json['ano']}/#{turma_json['semestre']}) da matéria '#{turma_json['materia_codigo']}': #{e.message}"
  end

  # == Descrição
  # Cria ou atualiza o registro de Turma correspondente aos dados
  # informados e à matéria já localizada.
  #
  # == Argumentos
  # * +turma_json+ - Hash com os dados da turma, contendo (ao menos) as
  #   chaves +"numero"+, +"ano"+ e +"semestre"+.
  # * +materia+ - instância de Materia à qual a turma pertence.
  #
  # == Retorno
  # * Retorna a instância de Turma criada/atualizada e já persistida.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: busca (ou inicializa) e salva
  #   (+turma.save!+, que pode levantar exceção em caso de falha de
  #   validação, propagada ao chamador) o registro de Turma.
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

  # == Descrição
  # Itera sobre a lista de docentes do JSON de importação, delegando a
  # criação/atualização de cada um a +importar_docente_sigaa+.
  #
  # == Argumentos
  # * +dados+ - Hash com os dados completos do JSON de importação
  #   (utiliza a chave +"usuarios_docentes"+).
  # * +contexto+ - Hash de acumuladores, atualizado por referência.
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: delegado a +importar_docente_sigaa+,
  #   chamado uma vez para cada docente.
  def importar_docentes_sigaa(dados, contexto)
    dados["usuarios_docentes"]&.each do |docente_json|
      importar_docente_sigaa(docente_json, contexto)
    end
  end

  # == Descrição
  # Cria/atualiza o Usuario e o PerfilDocente correspondentes a um
  # docente do JSON de importação, sincronizando suas participações nas
  # turmas lecionadas (removendo as que não constam mais na lista).
  #
  # == Argumentos
  # * +docente_json+ - Hash com os dados do docente, contendo (ao menos)
  #   as chaves +"matricula"+, +"nome"+, +"email"+,
  #   +"departamento_id_temp"+ e, opcionalmente, +"turmas_lecionadas"+.
  # * +contexto+ - Hash de acumuladores, atualizado por referência (a
  #   matrícula é adicionada a +:matriculas_ativas_json+, e uma
  #   eventual mensagem de erro é adicionada a +:erros_importacao+).
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: dentro de uma transação, cria/atualiza
  #   o Usuario e o PerfilDocente, cria as ParticipacaoTurma das turmas
  #   lecionadas e remove as participações do tipo docente que não
  #   constam mais na lista. Em caso de exceção, a transação é
  #   revertida e uma mensagem de erro é registrada em
  #   +contexto[:erros_importacao]+ (a exceção não é propagada).
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

  # == Descrição
  # Cria ou atualiza o PerfilDocente associado a um usuário importado,
  # definindo seu departamento.
  #
  # == Argumentos
  # * +usuario+ - instância de Usuario para o qual o perfil será
  #   criado/atualizado.
  # * +docente_json+ - Hash com os dados do docente, contendo a chave
  #   +"departamento_id_temp"+.
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador (o valor de
  #   retorno é o de +perfil.save!+).
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: busca (ou inicializa) e salva
  #   (+perfil.save!+, que pode levantar exceção em caso de falha de
  #   validação, propagada ao chamador) o registro de PerfilDocente.
  def salvar_perfil_docente_sigaa!(usuario, docente_json)
    perfil = PerfilDocente.find_or_initialize_by(id: usuario.id)
    perfil.departamento_id = docente_json["departamento_id_temp"]
    perfil.save!
  end

  # == Descrição
  # Cria as participações em turma (tipo docente) do usuário para cada
  # turma listada em +"turmas_lecionadas"+, delegando a
  # +importar_participacao_sigaa!+.
  #
  # == Argumentos
  # * +usuario+ - instância de Usuario (docente) para o qual as
  #   participações serão criadas.
  # * +docente_json+ - Hash com os dados do docente, contendo
  #   (opcionalmente) a chave +"turmas_lecionadas"+.
  #
  # == Retorno
  # * Retorna um Array de Integer com os IDs de todas as turmas
  #   processadas para o docente.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: delegado a
  #   +importar_participacao_sigaa!+, chamado uma vez para cada turma
  #   lecionada.
  def importar_participacoes_docente_sigaa!(usuario, docente_json)
    turmas_docente_ids = []
    (docente_json["turmas_lecionadas"] || []).each do |mat_json|
      importar_participacao_sigaa!(usuario, mat_json, :docente, turmas_docente_ids)
    end
    turmas_docente_ids
  end

  # == Descrição
  # Itera sobre a lista de discentes do JSON de importação, delegando a
  # criação/atualização de cada um a +importar_discente_sigaa+.
  #
  # == Argumentos
  # * +dados+ - Hash com os dados completos do JSON de importação
  #   (utiliza a chave +"usuarios_discentes"+).
  # * +contexto+ - Hash de acumuladores, atualizado por referência.
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: delegado a +importar_discente_sigaa+,
  #   chamado uma vez para cada discente.
  def importar_discentes_sigaa(dados, contexto)
    dados["usuarios_discentes"]&.each do |discente_json|
      importar_discente_sigaa(discente_json, contexto)
    end
  end

  # == Descrição
  # Cria/atualiza o Usuario e o PerfilDiscente correspondentes a um
  # discente do JSON de importação, sincronizando suas participações nas
  # turmas matriculadas (removendo as que não constam mais na lista).
  #
  # == Argumentos
  # * +discente_json+ - Hash com os dados do discente, contendo (ao
  #   menos) as chaves +"matricula"+, +"nome"+, +"email"+ e
  #   +"turmas_matriculadas"+.
  # * +contexto+ - Hash de acumuladores, atualizado por referência (a
  #   matrícula é adicionada a +:matriculas_ativas_json+, e uma
  #   eventual mensagem de erro é adicionada a +:erros_importacao+).
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: dentro de uma transação, cria/atualiza
  #   o Usuario, cria o PerfilDiscente (se ainda não existir), cria as
  #   ParticipacaoTurma das turmas matriculadas e remove todas as
  #   participações do usuário que não constam mais na lista. Em caso
  #   de exceção, a transação é revertida e uma mensagem de erro é
  #   registrada em +contexto[:erros_importacao]+ (a exceção não é
  #   propagada).
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

  # == Descrição
  # Cria as participações em turma (tipo discente) do usuário para cada
  # turma listada em +"turmas_matriculadas"+, delegando a
  # +importar_participacao_sigaa!+.
  #
  # == Argumentos
  # * +usuario+ - instância de Usuario (discente) para o qual as
  #   participações serão criadas.
  # * +discente_json+ - Hash com os dados do discente, contendo a chave
  #   +"turmas_matriculadas"+.
  #
  # == Retorno
  # * Retorna um Array de Integer com os IDs de todas as turmas
  #   processadas para o discente.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: delegado a
  #   +importar_participacao_sigaa!+, chamado uma vez para cada turma
  #   matriculada.
  def importar_participacoes_discente_sigaa!(usuario, discente_json)
    turmas_aluno_ids = []
    discente_json["turmas_matriculadas"].each do |mat_json|
      importar_participacao_sigaa!(usuario, mat_json, :discente, turmas_aluno_ids)
    end
    turmas_aluno_ids
  end

  # == Descrição
  # Cria ou atualiza o registro de Usuario correspondente aos dados
  # importados, inicializando-o com valores padrão apenas se for um
  # registro novo (para não sobrescrever status/senha de usuários já
  # existentes).
  #
  # == Argumentos
  # * +usuario_json+ - Hash com os dados do usuário, contendo (ao menos)
  #   as chaves +"nome"+ e +"email"+.
  # * +matricula+ - String com a matrícula usada para localizar (ou
  #   criar) o Usuario.
  #
  # == Retorno
  # * Retorna a instância de Usuario criada/atualizada e já persistida.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: busca (ou inicializa) e salva
  #   (+usuario.save!+, que pode levantar exceção em caso de falha de
  #   validação, propagada ao chamador) o registro de Usuario.
  def salvar_usuario_importado_sigaa!(usuario_json, matricula)
    usuario = Usuario.find_or_initialize_by(matricula: matricula)
    usuario.nome = usuario_json["nome"]
    usuario.email = usuario_json["email"]
    inicializar_usuario_importado_sigaa(usuario)
    usuario.save!
    usuario
  end

  # == Descrição
  # Define os valores padrão (+status+ e +senha+) para um Usuario recém
  # criado durante a importação, sem afetar usuários já existentes.
  #
  # == Argumentos
  # * +usuario+ - instância de Usuario (ainda não persistida ou já
  #   existente) a ser eventualmente inicializada.
  #
  # == Retorno
  # * Não possui retorno relevante; interrompe a execução (via +return+)
  #   caso o usuário não seja um registro novo.
  #
  # == Efeitos Colaterais
  # * Altera os atributos +status+ e +senha+ do objeto +usuario+ em
  #   memória, apenas quando +usuario.new_record?+ for verdadeiro (a
  #   gravação no banco ocorre em +salvar_usuario_importado_sigaa!+).
  def inicializar_usuario_importado_sigaa(usuario)
    return unless usuario.new_record?

    usuario.status = 0
    usuario.senha = ""
  end

  # == Descrição
  # Localiza a turma referenciada nos dados informados e cria a
  # ParticipacaoTurma correspondente para o usuário, registrando o ID
  # da turma na lista de acumulação.
  #
  # == Argumentos
  # * +usuario+ - instância de Usuario para o qual a participação será
  #   criada.
  # * +mat_json+ - Hash com os dados de identificação da turma (no
  #   formato aceito por +encontrar_turma_sigaa!+).
  # * +tipo_participacao+ - Symbol, +:docente+ ou +:discente+, indicando
  #   o tipo da participação a ser criada.
  # * +turmas_ids+ - Array de Integer no qual o ID da turma localizada
  #   será adicionado (por referência).
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador (o valor de
  #   retorno é o de +ParticipacaoTurma.find_or_create_by!+).
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: leitura da turma (via +encontrar_turma_sigaa!+,
  #   que pode levantar exceção caso não seja encontrada) e escrita da
  #   ParticipacaoTurma (via +find_or_create_by!+). *Array externo*:
  #   adiciona o ID da turma a +turmas_ids+.
  def importar_participacao_sigaa!(usuario, mat_json, tipo_participacao, turmas_ids)
    turma = encontrar_turma_sigaa!(mat_json)
    turmas_ids << turma.id
    ParticipacaoTurma.find_or_create_by!(
      usuario_id: usuario.id,
      turma_id: turma.id,
      tipo_participacao: tipo_participacao
    )
  end

  # == Descrição
  # Localiza uma Materia pelo código informado, levantando exceção caso
  # não exista.
  #
  # == Argumentos
  # * +codigo+ - String com o código da matéria a ser buscada.
  #
  # == Retorno
  # * Retorna a instância de Materia encontrada.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura. Levanta uma exceção
  #   (+RuntimeError+, via +raise+) caso a matéria não seja encontrada.
  def encontrar_materia_sigaa!(codigo)
    materia = Materia.find_by(codigo: codigo)
    raise "Matéria com código '#{codigo}' não existe no sistema." if materia.nil?

    materia
  end

  # == Descrição
  # Localiza a Turma correspondente aos dados informados, a partir da
  # matéria, número, ano e semestre, levantando exceção caso não seja
  # encontrada.
  #
  # == Argumentos
  # * +mat_json+ - Hash com os dados de identificação da turma,
  #   contendo (ao menos) as chaves +"materia_codigo"+,
  #   +"numero_turma"+, +"ano"+ e +"semestre"+.
  #
  # == Retorno
  # * Retorna a instância de Turma encontrada.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, incluindo a busca da matéria
  #   (via +encontrar_materia_sigaa!+, que pode levantar exceção).
  #   Levanta uma exceção (+RuntimeError+, via +raise+) caso a turma
  #   não seja encontrada.
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

  # == Descrição
  # Remove, ao final da importação, os registros de Turma, Materia e
  # Usuario que não constam mais como ativos no contexto acumulado
  # durante o processamento do arquivo do SIGAA.
  #
  # == Argumentos
  # * +contexto+ - Hash de acumuladores (ver
  #   +contexto_importacao_sigaa+), já preenchido pelas etapas
  #   anteriores de importação.
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: dentro de uma única transação, remove
  #   (+destroy_all+) todas as Turmas cujo ID não está em
  #   +contexto[:turmas_ativas_ids]+, todas as Materias cujo código não
  #   está em +contexto[:codigos_materias_ativos]+, e delega a remoção
  #   de usuários a +remover_usuarios_importacao_sigaa+. Caso qualquer
  #   remoção falhe, toda a transação é revertida.
  def sincronizar_remocoes_sigaa(contexto)
    ActiveRecord::Base.transaction do
      Turma.where.not(id: contexto[:turmas_ativas_ids]).destroy_all
      Materia.where.not(codigo: contexto[:codigos_materias_ativos]).destroy_all
      remover_usuarios_importacao_sigaa(contexto[:matriculas_ativas_json])
    end
  end

  # == Descrição
  # Remove os usuários cuja matrícula não consta mais na lista de
  # matrículas ativas da importação, preservando sempre os usuários
  # administradores.
  #
  # == Argumentos
  # * +matriculas_ativas_json+ - Array de String com as matrículas que
  #   permaneceram ativas na importação e, portanto, não devem ser
  #   removidas.
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados (Escrita)*: remove (+usuario.destroy!+) cada
  #   Usuario cuja matrícula não está na lista informada, exceto os que
  #   são administradores (+usuario.administrador?+).
  def remover_usuarios_importacao_sigaa(matriculas_ativas_json)
    Usuario.where.not(matricula: matriculas_ativas_json).each do |usuario|
      next if usuario.administrador?

      usuario.destroy!
    end
  end

  # == Descrição
  # Redireciona para a tela de gerenciamento com a mensagem flash
  # apropriada ao resultado da importação (sucesso total ou parcial).
  #
  # == Argumentos
  # * +erros_importacao+ - Array de String com as mensagens de erro
  #   ocorridas durante a importação.
  #
  # == Retorno
  # * Retorna o resultado de +redirect_to+. Possui duas mensagens
  #   possíveis, de acordo com a presença de erros.
  #
  # == Efeitos Colaterais
  # * *Redirecionamento*: redireciona para +gerenciamento_path+ com
  #   flash de sucesso (sem erros) ou de erro (incluindo
  #   +error_list+, quando há falhas).
  def redirecionar_importacao_sigaa(erros_importacao)
    if erros_importacao.empty?
      redirect_to gerenciamento_path, flash: { success: "Dados do SIGAA importados e sincronizados com sucesso!" }
    else
      redirect_to gerenciamento_path, flash: { error: "A importação foi concluída parcialmente.", error_list: erros_importacao }
    end
  end

  # == Descrição
  # Inicializa as variáveis de instância utilizadas pela tela de
  # pesquisa, antes de decidir qual fluxo de busca (por turma ou por
  # termo) será executado.
  #
  # == Argumentos
  # * Consome +params[:q]+ e os parâmetros de filtro processados por
  #   +tipos_selecionados+.
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador.
  #
  # == Efeitos Colaterais
  # * Popula as variáveis de instância +@termo+, +@avaliacoes+,
  #   +@templates+, +@formularios+ (inicializadas como relações
  #   vazias) e +@tipos_selecionados+. Nenhuma alteração no banco de
  #   dados.
  def inicializar_pesquisa
    @termo = params[:q].to_s.strip
    @avaliacoes = Avaliacao.none
    @templates = Template.none
    @formularios = Formulario.none
    @tipos_selecionados = tipos_selecionados
  end

  # == Descrição
  # Executa a pesquisa restrita a uma turma específica (informada via
  # +params[:turma_id]+), populando avaliações e, para administradores,
  # formulários da turma.
  #
  # == Argumentos
  # * Consome +params[:turma_id]+ e +@tipos_selecionados+.
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, delegada a
  #   +avaliacoes_da_turma+/+formularios_da_turma+. Popula
  #   +@avaliacoes+ e, se aplicável, +@formularios+.
  def pesquisar_por_turma
    turma_id = params[:turma_id]
    @avaliacoes = avaliacoes_da_turma(turma_id) if tipo_selecionado?("avaliacoes")
    @formularios = formularios_da_turma(turma_id) if administrador_com_tipo?("formularios")
  end

  # == Descrição
  # Executa a pesquisa por termo livre, populando avaliações para
  # qualquer usuário e, adicionalmente, templates e formulários para
  # administradores.
  #
  # == Argumentos
  # * Consome +@termo+ (via +padrao_pesquisa+) e +@tipos_selecionados+.
  #
  # == Retorno
  # * Não possui retorno relevante utilizado pelo chamador; interrompe
  #   a execução (via +return+) após popular avaliações, caso o
  #   usuário não seja administrador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, delegada a
  #   +pesquisar_avaliacoes+/+pesquisar_templates+/+pesquisar_formularios+.
  #   Popula +@avaliacoes+ e, se aplicável, +@templates+ e
  #   +@formularios+.
  def pesquisar_por_termo
    padrao = padrao_pesquisa
    @avaliacoes = pesquisar_avaliacoes(padrao) if tipo_selecionado?("avaliacoes")

    return unless current_user.administrador?

    @templates = pesquisar_templates(padrao) if tipo_selecionado?("templates")
    @formularios = pesquisar_formularios(padrao) if tipo_selecionado?("formularios")
  end

  # == Descrição
  # Monta o padrão utilizado nas cláusulas SQL +LIKE+ a partir do termo
  # de pesquisa atual, já sanitizado e em minúsculas.
  #
  # == Argumentos
  # * Nenhum diretamente. Utiliza +@termo+.
  #
  # == Retorno
  # * Retorna uma String no formato +"%termo%"+, com o termo sanitizado
  #   via +ActiveRecord::Base.sanitize_sql_like+.
  #
  # == Efeitos Colaterais
  # * Nenhum.
  def padrao_pesquisa
    "%#{ActiveRecord::Base.sanitize_sql_like(@termo.downcase)}%"
  end

  # == Descrição
  # Verifica se um determinado tipo de resultado (ex.: "avaliacoes",
  # "templates", "formularios") está entre os tipos selecionados pelo
  # filtro de pesquisa atual.
  #
  # == Argumentos
  # * +tipo+ - String com o identificador do tipo a ser verificado.
  #
  # == Retorno
  # * Retorna +true+ se o tipo estiver presente em
  #   +@tipos_selecionados+, +false+ caso contrário.
  #
  # == Efeitos Colaterais
  # * Nenhum.
  def tipo_selecionado?(tipo)
    @tipos_selecionados.include?(tipo)
  end

  # == Descrição
  # Verifica se o usuário atual é administrador e se, ao mesmo tempo, o
  # tipo informado está selecionado no filtro de pesquisa.
  #
  # == Argumentos
  # * +tipo+ - String com o identificador do tipo a ser verificado.
  #
  # == Retorno
  # * Retorna +true+ se +current_user.administrador?+ e o tipo estiver
  #   selecionado, +false+ caso contrário.
  #
  # == Efeitos Colaterais
  # * Nenhum.
  def administrador_com_tipo?(tipo)
    current_user.administrador? && tipo_selecionado?(tipo)
  end

  # == Descrição
  # Monta a lista completa de sugestões de busca para o termo informado,
  # combinando sugestões básicas (turmas e matérias), de avaliações e,
  # quando aplicável, de itens restritos a administradores (templates e
  # formulários).
  #
  # == Argumentos
  # * +termo+ - String com o termo de pesquisa (não sanitizado).
  #
  # == Retorno
  # * Retorna um Array de Hash, cada um representando uma sugestão
  #   (com chaves como +:tipo+, +:titulo+, +:subtitulo+ e +:url+,
  #   variáveis conforme o tipo de sugestão).
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, delegada aos métodos de
  #   sugestão individuais.
  def sugestoes_do_termo(termo)
    tipos = tipos_selecionados
    padrao = "%#{ActiveRecord::Base.sanitize_sql_like(termo.downcase)}%"

    sugestoes_basicas(termo, padrao, tipos) +
      sugestoes_avaliacoes(padrao, tipos) +
      sugestoes_administrador(padrao, tipos)
  end

  # == Descrição
  # Combina as sugestões de turmas e de matérias, disponíveis para
  # qualquer usuário autenticado.
  #
  # == Argumentos
  # * +termo+ - String com o termo de pesquisa (não sanitizado, usado
  #   para a busca de turmas).
  # * +padrao+ - String já no formato +"%termo%"+, sanitizada (usada
  #   para a busca de matérias).
  # * +tipos+ - Array de String com os tipos de resultado atualmente
  #   selecionados (repassado para compor as URLs das sugestões).
  #
  # == Retorno
  # * Retorna um Array de Hash com as sugestões de turmas seguidas das
  #   sugestões de matérias.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, delegada a
  #   +sugestoes_turmas+/+sugestoes_materias+.
  def sugestoes_basicas(termo, padrao, tipos)
    sugestoes_turmas(termo, tipos) + sugestoes_materias(padrao, tipos)
  end

  # == Descrição
  # Busca até 3 turmas correspondentes ao termo informado e as
  # transforma em sugestões formatadas para exibição.
  #
  # == Argumentos
  # * +termo+ - String com o termo de pesquisa (repassado a
  #   +pesquisar_turmas+).
  # * +tipos+ - Array de String com os tipos de resultado atualmente
  #   selecionados (repassado para compor a URL de cada sugestão).
  #
  # == Retorno
  # * Retorna um Array de Hash (tipo "Turma"), cada um contendo
  #   +:tipo+, +:titulo+, +:subtitulo+, +:materia_codigo+,
  #   +:turma_codigo+ e +:url+.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, delegada a +pesquisar_turmas+.
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

  # == Descrição
  # Busca até 3 matérias correspondentes ao padrão informado e as
  # transforma em sugestões formatadas para exibição.
  #
  # == Argumentos
  # * +padrao+ - String já no formato +"%termo%"+, sanitizada
  #   (repassada a +pesquisar_materias+).
  # * +tipos+ - Array de String com os tipos de resultado atualmente
  #   selecionados (repassado para compor a URL de cada sugestão).
  #
  # == Retorno
  # * Retorna um Array de Hash (tipo "Matéria"), cada um contendo
  #   +:tipo+, +:titulo+, +:subtitulo+, +:materia_codigo+ e +:url+.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, delegada a +pesquisar_materias+.
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

  # == Descrição
  # Busca até 5 avaliações correspondentes ao padrão informado, caso o
  # tipo "avaliacoes" esteja selecionado, e as transforma em sugestões
  # formatadas para exibição.
  #
  # == Argumentos
  # * +padrao+ - String já no formato +"%termo%"+, sanitizada
  #   (repassada a +pesquisar_avaliacoes+).
  # * +tipos+ - Array de String com os tipos de resultado atualmente
  #   selecionados.
  #
  # == Retorno
  # * Retorna um Array de Hash (tipo "Avaliação"), ou um Array vazio
  #   caso "avaliacoes" não esteja entre os tipos selecionados.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, delegada a
  #   +pesquisar_avaliacoes+.
  def sugestoes_avaliacoes(padrao, tipos)
    return [] unless tipos.include?("avaliacoes")

    pesquisar_avaliacoes(padrao).limit(5).map do |avaliacao|
      sugestao_avaliacao(avaliacao)
    end
  end

  # == Descrição
  # Monta o Hash de sugestão formatado para uma única avaliação.
  #
  # == Argumentos
  # * +avaliacao+ - instância de Avaliacao a ser formatada como
  #   sugestão.
  #
  # == Retorno
  # * Retorna um Hash com +:tipo+, +:titulo+, +:subtitulo+,
  #   +:materia_codigo+, +:turma_codigo+ e +:url+.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura (navegação pelas associações
  #   +formulario+, +turma+, +materia+ e +template+ da avaliação, que
  #   pode disparar consultas adicionais caso não estejam
  #   pré-carregadas).
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

  # == Descrição
  # Combina as sugestões restritas a administradores (templates e
  # formulários), retornando uma lista vazia para usuários comuns.
  #
  # == Argumentos
  # * +padrao+ - String já no formato +"%termo%"+, sanitizada
  #   (repassada aos métodos de sugestão).
  # * +tipos+ - Array de String com os tipos de resultado atualmente
  #   selecionados.
  #
  # == Retorno
  # * Retorna um Array de Hash com as sugestões de templates seguidas
  #   das sugestões de formulários, ou um Array vazio caso
  #   +current_user+ não seja administrador.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, delegada a
  #   +sugestoes_templates+/+sugestoes_formularios+.
  def sugestoes_administrador(padrao, tipos)
    return [] unless current_user.administrador?

    sugestoes_templates(padrao, tipos) + sugestoes_formularios(padrao, tipos)
  end

  # == Descrição
  # Busca até 5 templates correspondentes ao padrão informado, caso o
  # tipo "templates" esteja selecionado, e os transforma em sugestões
  # formatadas para exibição.
  #
  # == Argumentos
  # * +padrao+ - String já no formato +"%termo%"+, sanitizada
  #   (repassada a +pesquisar_templates+).
  # * +tipos+ - Array de String com os tipos de resultado atualmente
  #   selecionados.
  #
  # == Retorno
  # * Retorna um Array de Hash (tipo "Template"), ou um Array vazio
  #   caso "templates" não esteja entre os tipos selecionados.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, delegada a
  #   +pesquisar_templates+ (que já aplica a política de acesso via
  #   +policy_scope+).
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

  # == Descrição
  # Busca até 5 formulários correspondentes ao padrão informado, caso o
  # tipo "formularios" esteja selecionado, e os transforma em sugestões
  # formatadas para exibição.
  #
  # == Argumentos
  # * +padrao+ - String já no formato +"%termo%"+, sanitizada
  #   (repassada a +pesquisar_formularios+).
  # * +tipos+ - Array de String com os tipos de resultado atualmente
  #   selecionados.
  #
  # == Retorno
  # * Retorna um Array de Hash (tipo "Formulário"), ou um Array vazio
  #   caso "formularios" não esteja entre os tipos selecionados.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, delegada a
  #   +pesquisar_formularios+ (restrita ao departamento do
  #   administrador atual).
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

  # Sem o filtro aberto, assume as 3 categorias. Com o filtro aberto, usa
  # exatamente o que está marcado. "sem_templates" força a exclusão mesmo
  # que "templates" venha marcado por algum motivo (defesa, não deveria
  # acontecer já que o checkbox fica desabilitado nesse caso).
  #
  # == Descrição
  # Determina, a partir dos parâmetros da requisição, quais tipos de
  # resultado (avaliações, templates, formulários) devem ser
  # considerados na pesquisa ou nas sugestões atuais.
  #
  # == Argumentos
  # * Nenhum diretamente. Utiliza +params[:filtro_ativo]+,
  #   +params[:tipos]+ e +params[:sem_templates]+.
  #
  # == Retorno
  # * Retorna um Array de String com os tipos selecionados (ex.:
  #   +%w[avaliacoes templates formularios]+, ou um subconjunto,
  #   possivelmente sem "templates").
  #
  # == Efeitos Colaterais
  # * Nenhum.
  def tipos_selecionados
    tipos = if params[:filtro_ativo].present?
              Array(params[:tipos])
    else
              %w[avaliacoes templates formularios]
    end

    tipos -= [ "templates" ] if params[:sem_templates] == "1"
    tipos
  end

  # == Descrição
  # before_action que garante que apenas usuários autenticados possam
  # acessar as actions de índice, pesquisa e sugestões.
  #
  # == Argumentos
  # * Nenhum diretamente. Utiliza +current_user+.
  #
  # == Retorno
  # * Não possui retorno relevante (callback de before_action).
  #
  # == Efeitos Colaterais
  # * *Redirecionamento*: caso não haja usuário autenticado, redireciona
  #   para a página inicial com flash de erro, impedindo o
  #   processamento da action solicitada.
  def verificar_usuario
    return if current_user.present?

    redirect_to root_path,
      flash: { error: "Acesso restrito. Por favor, faça login para continuar." }
  end

  # == Descrição
  # Monta a consulta base das avaliações pendentes do usuário
  # autenticado, com as associações necessárias pré-carregadas,
  # ordenadas da mais recente para a mais antiga.
  #
  # == Argumentos
  # * Nenhum diretamente. Utiliza +current_user.id+.
  #
  # == Retorno
  # * Retorna um +ActiveRecord::Relation+ de Avaliacao (ainda não
  #   executado), podendo ser encadeado com filtros adicionais pelos
  #   métodos chamadores.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, executada de forma lazy quando
  #   a relação for de fato utilizada.
  def avaliacoes_do_usuario
    Avaliacao
      .pendentes
      .joins(:participacao_turma)
      .where(participacoes_turmas: { usuario_id: current_user.id })
      .includes(formulario: [ :template, { turma: :materia } ])
      .order(created_at: :desc)
  end

  # == Descrição
  # Filtra as avaliações pendentes do usuário restritas a uma turma
  # específica.
  #
  # == Argumentos
  # * +turma_id+ - ID da Turma pela qual as avaliações serão filtradas.
  #
  # == Retorno
  # * Retorna um +ActiveRecord::Relation+ de Avaliacao, filtrado pela
  #   turma informada.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, executada de forma lazy.
  def avaliacoes_da_turma(turma_id)
    avaliacoes_do_usuario
      .joins(:formulario)
      .where(formularios: { turma_id: turma_id })
  end

  # == Descrição
  # Busca os formulários mais recentes de uma turma específica dentro do
  # departamento do administrador autenticado.
  #
  # == Argumentos
  # * +turma_id+ - ID da Turma pela qual os formulários serão
  #   filtrados.
  #
  # == Retorno
  # * Retorna um +ActiveRecord::Relation+ de Formulario, restrito ao
  #   departamento do administrador atual e à turma informada.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, executada de forma lazy.
  #   Consome +current_administrador.departamento+.
  def formularios_da_turma(turma_id)
    Formulario
      .do_departamento(current_administrador.departamento)
      .where(turma_id: turma_id)
      .includes(:template, turma: :materia)
      .recentes
  end

  # == Descrição
  # Filtra as avaliações pendentes do usuário cujo título do template,
  # nome ou código da matéria correspondam ao padrão de pesquisa.
  #
  # == Argumentos
  # * +padrao+ - String já no formato +"%termo%"+, sanitizada.
  #
  # == Retorno
  # * Retorna um +ActiveRecord::Relation+ de Avaliacao filtrado pelo
  #   padrão informado.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, executada de forma lazy.
  def pesquisar_avaliacoes(padrao)
    avaliacoes_do_usuario
      .joins(formulario: [ :template, { turma: :materia } ])
      .where(
        "LOWER(templates.titulo) LIKE :padrao OR LOWER(materias.nome) LIKE :padrao OR LOWER(materias.codigo) LIKE :padrao",
        padrao: padrao
      )
  end

  # == Descrição
  # Busca os templates (restritos pela política de acesso do usuário
  # atual) cujo título ou descrição correspondam ao padrão de pesquisa.
  #
  # == Argumentos
  # * +padrao+ - String já no formato +"%termo%"+, sanitizada.
  #
  # == Retorno
  # * Retorna um +ActiveRecord::Relation+ de Template, filtrado e
  #   ordenado pelos mais recentes.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, executada de forma lazy. Aplica
  #   +policy_scope(Template)+, que pode disparar verificações de
  #   autorização.
  def pesquisar_templates(padrao)
    policy_scope(Template)
      .where(
        "LOWER(templates.titulo) LIKE :padrao OR " \
          "LOWER(COALESCE(templates.descricao, '')) LIKE :padrao",
        padrao: padrao
      )
      .recentes
  end

  # == Descrição
  # Busca os formulários do departamento do administrador atual cujo
  # título do template, nome ou código da matéria correspondam ao
  # padrão de pesquisa.
  #
  # == Argumentos
  # * +padrao+ - String já no formato +"%termo%"+, sanitizada.
  #
  # == Retorno
  # * Retorna um +ActiveRecord::Relation+ de Formulario, filtrado e
  #   ordenado pelos mais recentes.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, executada de forma lazy.
  #   Consome +current_administrador.departamento+.
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

  # == Descrição
  # Busca as matérias cujo nome ou código correspondam ao padrão de
  # pesquisa, ordenadas por nome.
  #
  # == Argumentos
  # * +padrao+ - String já no formato +"%termo%"+, sanitizada.
  #
  # == Retorno
  # * Retorna um +ActiveRecord::Relation+ de Materia, filtrado e
  #   ordenado por nome.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, executada de forma lazy.
  def pesquisar_materias(padrao)
    Materia.where(
      "LOWER(nome) LIKE :padrao OR LOWER(codigo) LIKE :padrao",
      padrao: padrao
    ).order(:nome)
  end

  # Espera o último "token" do termo como identificador de turma (letra ou
  # número) e o restante como nome/código da matéria. Ex.: "CIC0001 A",
  # "Estruturas de Dados 1".
  #
  # == Descrição
  # Interpreta o termo de pesquisa como "<matéria> <identificador da
  # turma>" e busca as turmas correspondentes, combinando o número da
  # turma com o nome/código da matéria.
  #
  # == Argumentos
  # * +termo+ - String com o termo de pesquisa completo, não
  #   sanitizado.
  #
  # == Retorno
  # * Retorna um +ActiveRecord::Relation+ de Turma correspondente ao
  #   padrão interpretado, ou +Turma.none+ caso o termo não corresponda
  #   ao formato esperado (regex) ou o nome da matéria extraído esteja
  #   em branco.
  #
  # == Efeitos Colaterais
  # * *Banco de Dados*: apenas leitura, executada de forma lazy.
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

  # Matéria/turma não têm relação com templates, então qualquer navegação
  # a partir dessas sugestões já remove "templates" da lista de tipos e
  # marca sem_templates=1, para a topbar desabilitar esse checkbox.
  #
  # == Descrição
  # Monta a URL de pesquisa a ser usada quando o usuário clica na
  # sugestão de uma matéria, ajustando os tipos de resultado para
  # excluir "templates".
  #
  # == Argumentos
  # * +materia+ - instância de Materia cujo nome será usado como termo
  #   de pesquisa na URL gerada.
  # * +tipos+ - Array de String com os tipos de resultado atualmente
  #   selecionados.
  #
  # == Retorno
  # * Retorna uma String com a URL gerada por +pesquisa_path+, já com
  #   +filtro_ativo+, +tipos+ (sem "templates") e +sem_templates+
  #   definidos.
  #
  # == Efeitos Colaterais
  # * Nenhum.
  def materia_suggestion_url(materia, tipos)
    tipos_aplicaveis = tipos - [ "templates" ]
    tipos_aplicaveis = %w[avaliacoes formularios] if tipos_aplicaveis.empty?

    pesquisa_path(q: materia.nome, filtro_ativo: "1", tipos: tipos_aplicaveis, sem_templates: "1")
  end

  # == Descrição
  # Monta a URL de pesquisa a ser usada quando o usuário clica na
  # sugestão de uma turma, ajustando os tipos de resultado para excluir
  # "templates" e restringindo o resultado à turma selecionada.
  #
  # == Argumentos
  # * +turma+ - instância de Turma cujo nome de exibição será usado
  #   como termo de pesquisa e cujo ID será incluído na URL gerada.
  # * +tipos+ - Array de String com os tipos de resultado atualmente
  #   selecionados.
  #
  # == Retorno
  # * Retorna uma String com a URL gerada por +pesquisa_path+, já com
  #   +filtro_ativo+, +tipos+ (sem "templates"), +sem_templates+ e
  #   +turma_id+ definidos.
  #
  # == Efeitos Colaterais
  # * Nenhum.
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

  # == Descrição
  # before_action que garante que apenas usuários autenticados e com
  # perfil de administrador possam acessar as actions de gerenciamento,
  # importação de dados e envio de solicitações.
  #
  # == Argumentos
  # * Nenhum diretamente. Utiliza +current_user+.
  #
  # == Retorno
  # * Não possui retorno relevante (callback de before_action).
  #
  # == Efeitos Colaterais
  # * *Sessão*: caso o usuário não esteja autenticado ou não seja
  #   administrador, limpa a sessão (+session.clear+) e zera
  #   +@current_user+.
  # * *Redirecionamento*: nesses mesmos casos, redireciona para a
  #   página inicial com flash de erro, impedindo o processamento da
  #   action solicitada.
  def verificar_admin
    if current_user.nil? || !current_user.administrador?
      session.clear
      @current_user = nil
      redirect_to root_path, flash: { error: "Acesso restrito. Por favor, faça login como administrador." }
    end
  end
end

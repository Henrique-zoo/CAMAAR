# frozen_string_literal: true

# == Script de Seed
#
# Este script popula o banco de dados a partir do arquivo
# <tt>db/dados_iniciais.json</tt>, criando (ou atualizando, quando já
# existentes) os registros de Departamento, Materia, Turma, Usuario e os
# respectivos perfis (PerfilAdm, PerfilDocente, PerfilDiscente) e
# participações em turma (ParticipacaoTurma).
#
# A execução é dividida em blocos sequenciais (departamentos, matérias,
# turmas, administradores e docentes), sendo cada bloco responsável por
# ler a seção correspondente do JSON e persistir os dados no banco.

require 'json'

# Conteúdo bruto do arquivo de dados iniciais, em formato JSON.
arquivo = File.read(Rails.root.join('db', 'dados_iniciais.json'))

# Hash resultante do parse do arquivo +dados_iniciais.json+, contendo as
# chaves +departamentos+, +materias+, +turmas+, +usuarios_admin+ e
# +usuarios_docentes+.
dados   = JSON.parse(arquivo)

# Cria ou atualiza um Usuario a partir dos dados informados em
# +usuario_json+, definindo também sua senha.
#
# Argumentos:: +usuario_json+ - Hash com os dados do usuário extraídos do
#              JSON de seed, contendo (ao menos) as chaves +matricula+,
#              +nome+, +email+, +status+ e +password+.
# Retorno:: A instância de Usuario criada/atualizada e já persistida.
# Efeitos colaterais:: *Banco de Dados (Escrita)*: busca (ou inicializa)
#                      um Usuario pela +matricula+, atualiza seus
#                      atributos e senha, e o salva
#                      (+usuario.save!+, que levanta exceção em caso de
#                      falha de validação).
def salvar_usuario_seed!(usuario_json)
  usuario = Usuario.find_or_initialize_by(matricula: usuario_json['matricula'])
  usuario.assign_attributes(
    nome: usuario_json['nome'],
    email: usuario_json['email'],
    status: usuario_json['status']
  )
  usuario.senha = usuario_json['password']
  usuario.senha_confirmation = usuario_json['password']
  usuario.save!
  usuario
end

# Localiza, no banco de dados, a Turma correspondente aos dados
# informados em +turma_json+, validando previamente a existência da
# Materia associada.
#
# Argumentos::
# - +turma_json+ - Hash com os dados da turma extraídos do JSON de seed,
#   contendo (ao menos) as chaves +materia_codigo+, +numero_turma+,
#   +ano+ e +semestre+.
# - +contexto+ - String usada apenas para compor a mensagem de erro,
#   identificando a origem da busca (ex.: "o admin 123456").
# Retorno:: A instância de Turma encontrada.
# Efeitos colaterais:: *Banco de Dados*: realiza apenas operações de
#                      leitura (SELECT). Levanta uma exceção
#                      (+RuntimeError+, via +raise+) e interrompe a
#                      execução do script caso a Materia ou a Turma não
#                      sejam encontradas.
def encontrar_turma_seed!(turma_json, contexto)
  materia = Materia.find_by(codigo: turma_json['materia_codigo'])
  raise "Matéria '#{turma_json['materia_codigo']}' não encontrada para #{contexto}." if materia.nil?

  turma = Turma.find_by(
    materia_id: materia.id,
    numero: turma_json['numero_turma'],
    ano: turma_json['ano'],
    semestre: turma_json['semestre']
  )
  return turma if turma.present?

  raise "Turma nº #{turma_json['numero_turma']} (#{turma_json['ano']}/#{turma_json['semestre']}) " \
        "da matéria '#{materia.nome}' não encontrada para #{contexto}."
end

# Cria ou atualiza o PerfilAdm associado a um usuário, definindo seu
# departamento.
#
# Argumentos::
# - +usuario+ - instância de Usuario para o qual o perfil será
#   criado/atualizado (o PerfilAdm compartilha o mesmo +id+ do usuário).
# - +departamento_id+ - ID do Departamento a ser associado ao perfil.
# Retorno:: Não possui retorno relevante utilizado pelo chamador (o
#           valor de retorno é o de +perfil.save!+).
# Efeitos colaterais:: *Banco de Dados (Escrita)*: busca (ou inicializa)
#                      um PerfilAdm pelo +id+ do usuário, atualiza o
#                      +departamento_id+ e salva o registro
#                      (+perfil.save!+, que levanta exceção em caso de
#                      falha de validação).
def salvar_perfil_adm_seed!(usuario, departamento_id)
  perfil = PerfilAdm.find_or_initialize_by(id: usuario.id)
  perfil.departamento_id = departamento_id
  perfil.save!
end

# Cria ou atualiza o PerfilDocente associado a um usuário, definindo seu
# departamento.
#
# Argumentos::
# - +usuario+ - instância de Usuario para o qual o perfil será
#   criado/atualizado (o PerfilDocente compartilha o mesmo +id+ do
#   usuário).
# - +departamento_id+ - ID do Departamento a ser associado ao perfil.
# Retorno:: Não possui retorno relevante utilizado pelo chamador (o
#           valor de retorno é o de +perfil.save!+).
# Efeitos colaterais:: *Banco de Dados (Escrita)*: busca (ou inicializa)
#                      um PerfilDocente pelo +id+ do usuário, atualiza o
#                      +departamento_id+ e salva o registro
#                      (+perfil.save!+, que levanta exceção em caso de
#                      falha de validação).
def salvar_perfil_docente_seed!(usuario, departamento_id)
  perfil = PerfilDocente.find_or_initialize_by(id: usuario.id)
  perfil.departamento_id = departamento_id
  perfil.save!
end

# Retorna a associação de participações em turma de um usuário
# correspondente ao tipo de participação informado (docente ou
# discente).
#
# Argumentos::
# - +usuario+ - instância de Usuario cujas participações serão
#   consultadas.
# - +tipo_participacao+ - Symbol, +:docente+ ou +:discente+, indicando
#   qual escopo de participações deve ser retornado.
# Retorno:: Um +ActiveRecord::Relation+ com as participações em turma do
#           tipo informado (+usuario.participacoes_turma.docentes+ ou
#           +usuario.participacoes_turma.discentes+). Levanta uma
#           exceção (+RuntimeError+) caso +tipo_participacao+ seja
#           diferente de +:docente+ ou +:discente+.
# Efeitos colaterais:: Nenhum (apenas leitura em banco, realizada de
#                      forma lazy pelo +ActiveRecord::Relation+
#                      retornado).
def participacoes_seed(usuario, tipo_participacao)
  return usuario.participacoes_turma.docentes if tipo_participacao == :docente
  return usuario.participacoes_turma.discentes if tipo_participacao == :discente

  raise "Tipo de participação inválido: #{tipo_participacao}"
end

# Sincroniza as participações em turma de um usuário com a lista de
# turmas informada em +turmas_json+: garante a existência de uma
# ParticipacaoTurma para cada turma listada e remove as participações
# antigas (do mesmo tipo) que não constam mais na lista.
#
# Argumentos::
# - +usuario+ - instância de Usuario cujas participações serão
#   sincronizadas.
# - +turmas_json+ - Array de Hashes com os dados das turmas (no formato
#   aceito por +encontrar_turma_seed!+) que devem permanecer associadas
#   ao usuário.
# - +tipo_participacao+ - Symbol, +:docente+ ou +:discente+, indicando o
#   tipo das participações a serem sincronizadas.
# - +contexto+ - String usada para compor mensagens de erro (repassada a
#   +encontrar_turma_seed!+).
# Retorno:: Não possui retorno relevante utilizado pelo chamador (o
#           valor de retorno é o de +participacoes_antigas.destroy_all+).
# Efeitos colaterais:: *Banco de Dados (Escrita)*: cria uma
#                      ParticipacaoTurma para cada turma informada (caso
#                      ainda não exista, via +find_or_create_by!+) e
#                      remove (+destroy_all+) as participações do tipo
#                      informado que não estejam mais na lista de
#                      turmas. Pode levantar exceção caso alguma turma
#                      não seja encontrada (propagada de
#                      +encontrar_turma_seed!+).
def sincronizar_participacoes_seed!(usuario, turmas_json, tipo_participacao, contexto)
  turma_ids = turmas_json.map do |turma_json|
    turma = encontrar_turma_seed!(turma_json, contexto)
    ParticipacaoTurma.find_or_create_by!(
      usuario_id: usuario.id,
      turma_id: turma.id,
      tipo_participacao: tipo_participacao
    )
    turma.id
  end

  participacoes_antigas = participacoes_seed(usuario, tipo_participacao)
  participacoes_antigas = participacoes_antigas.where.not(turma_id: turma_ids) if turma_ids.any?
  participacoes_antigas.destroy_all
end

# Hash utilizado para mapear o +id_temporario+ de cada departamento
# (identificador usado apenas dentro do arquivo JSON de seed) para o
# +id+ real do registro de Departamento persistido no banco de dados.
# É preenchido no bloco de seed de departamentos e consultado no bloco
# de seed de matérias.
dept_mapeamento = {}

puts "Semeando Departamentos..."
# Bloco de seed: para cada departamento listado em +dados['departamentos']+,
# cria (ou reaproveita, caso já exista) o registro de Departamento pelo
# +nome+ e registra a correspondência entre o +id_temporario+ do JSON e o
# +id+ real do banco em +dept_mapeamento+.
#
# Efeitos colaterais: *Banco de Dados (Escrita)*: cria registros de
# Departamento via +find_or_create_by!+.
dados['departamentos'].each do |dept_json|
  dept_banco = Departamento.find_or_create_by!(nome: dept_json['nome'])
  dept_mapeamento[dept_json['id_temporario']] = dept_banco.id
end

puts "Semeando Matérias..."
# Bloco de seed: para cada matéria listada em +dados['materias']+, cria
# (caso ainda não exista, pelo +codigo+) o registro de Materia,
# associando-o ao Departamento correspondente através de
# +dept_mapeamento+.
#
# Efeitos colaterais: *Banco de Dados (Escrita)*: cria registros de
# Materia via +find_or_create_by!+.
dados['materias'].each do |mat_json|
  id_real = dept_mapeamento[mat_json['departamento_id_temp']]
  Materia.find_or_create_by!(codigo: mat_json['codigo']) do |m|
    m.nome           = mat_json['nome']
    m.departamento_id = id_real
  end
end

puts "Semeando Turmas..."
# Bloco de seed: para cada turma listada em +dados['turmas']+, localiza a
# Materia correspondente (pulando a turma, com aviso no console, caso a
# matéria não exista) e cria o registro de Turma, caso ainda não exista.
#
# Efeitos colaterais: *Banco de Dados (Escrita)*: cria registros de
# Turma via +find_or_create_by!+. *Console*: emite um aviso (+puts+)
# quando a matéria referenciada não é encontrada, sem interromper o
# restante do seed.
dados['turmas'].each do |turma_json|
  materia = Materia.find_by(codigo: turma_json['materia_codigo'])
  if materia.nil?
    puts "⚠️  Matéria #{turma_json['materia_codigo']} não encontrada."
    next
  end
  Turma.find_or_create_by!(
    numero:    turma_json['numero'],
    ano:       turma_json['ano'],
    semestre:  turma_json['semestre'],
    materia_id: materia.id
  )
end

puts "Semeando Administradores..."
# Bloco de seed: para cada administrador listado em
# +dados['usuarios_admin']+, cria/atualiza o Usuario (via
# +salvar_usuario_seed!+) e seu PerfilAdm (sempre criado, com
# departamento). De acordo com o campo +perfil+ ("docente" ou
# "discente"), também cria o perfil e as participações em turma
# correspondentes:
# - "docente": cria PerfilDocente e sincroniza as +turmas_lecionadas+
#   (opcionais) como participações do tipo +:docente+.
# - "discente": cria PerfilDiscente (sem departamento) e sincroniza as
#   +turmas_matriculadas+ (obrigatórias) como participações do tipo
#   +:discente+.
#
# Efeitos colaterais: *Banco de Dados (Escrita)*: cria/atualiza
# Usuario, PerfilAdm, PerfilDocente ou PerfilDiscente e
# ParticipacaoTurma, conforme descrito acima. Interrompe a execução do
# script (via +raise+) caso o perfil seja inválido/ausente ou caso um
# admin discente não possua +turmas_matriculadas+ definidas.
dados['usuarios_admin'].each do |admin_json|
  id_real = dept_mapeamento[admin_json['departamento_id_temp']]

  usuario = salvar_usuario_seed!(admin_json)

  # PerfilAdm — sempre criado, sempre com departamento
  salvar_perfil_adm_seed!(usuario, id_real)

  case admin_json['perfil']
  when 'docente'
    # Departamento vai para o PerfilDocente
    salvar_perfil_docente_seed!(usuario, id_real)

    # Turmas lecionadas (opcional: admin-docente pode não estar lecionando nada)
    turmas_lecionadas_json = admin_json['turmas_lecionadas'] || []
    sincronizar_participacoes_seed!(usuario, turmas_lecionadas_json, :docente, "o admin #{admin_json['matricula']}")

  when 'discente'
    # PerfilDiscente não recebe departamento
    PerfilDiscente.find_or_create_by!(id: usuario.id)

    # Matrícula nas turmas — obrigatório, erro encerra o seed se falhar
    turmas_json = admin_json['turmas_matriculadas'] || []
    raise "Admin discente #{admin_json['matricula']} não tem turmas_matriculadas definidas." if turmas_json.empty?

    sincronizar_participacoes_seed!(usuario, turmas_json, :discente, "o admin #{admin_json['matricula']}")

  else
    raise "Admin #{admin_json['matricula']} tem perfil inválido ou ausente: '#{admin_json['perfil']}'."
  end
end

puts "Semeando Docentes..."
# Bloco de seed: para cada docente listado em
# +dados['usuarios_docentes']+, cria/atualiza o Usuario (via
# +salvar_usuario_seed!+) e seu PerfilDocente (via
# +salvar_perfil_docente_seed!+), sincronizando em seguida as
# +turmas_lecionadas+ (opcionais) como participações do tipo
# +:docente+.
#
# Efeitos colaterais: *Banco de Dados (Escrita)*: cria/atualiza
# Usuario, PerfilDocente e ParticipacaoTurma, conforme descrito acima.
dados['usuarios_docentes'].to_a.each do |docente_json|
  id_real = dept_mapeamento[docente_json['departamento_id_temp']]
  usuario = salvar_usuario_seed!(docente_json)

  salvar_perfil_docente_seed!(usuario, id_real)
  sincronizar_participacoes_seed!(
    usuario,
    docente_json['turmas_lecionadas'] || [],
    :docente,
    "o docente #{docente_json['matricula']}"
  )
end

puts "Banco semeado com sucesso! 🎉"

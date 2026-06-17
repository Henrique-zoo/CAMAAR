# frozen_string_literal: true

Given(/^que existe um departamento chamado "([^"]+)"$/) do |nome|
  departamento_com_nome(nome)
end

Given(/^que existe um usuário administrador cadastrado no sistema$/) do
  estado[:usuario_administrador] = usuario_administrador
end

Given(/^que existe um usuário não administrador cadastrado no sistema$/) do
  estado[:usuario_nao_administrador] = usuario_nao_administrador
end

Given(/^que existe um usuário participante cadastrado no sistema$/) do
  estado[:usuario_participante] = usuario_participante
end

Given(/^que estou autenticado como administrador$/) do
  definir_usuario_atual(estado[:usuario_administrador] || usuario_administrador)
end

Given(/^que estou autenticado como administrador do "([^"]+)"$/) do |departamento|
  definir_usuario_atual(usuario_administrador(departamento: departamento))
end

Given(/^que existe um administrador pertencente ao departamento "([^"]+)"$/) do |departamento|
  estado[:administrador_do_contexto] = usuario_administrador(
    departamento: departamento
  )
end

Given(/^que estou autenticado como esse administrador$/) do
  definir_usuario_atual(estado.fetch(:administrador_do_contexto))
end

Given(/^que estou autenticado como participante$/) do
  definir_usuario_atual(estado[:usuario_participante] || usuario_participante)
end

Given(/^que estou autenticado como usuário não administrador$/) do
  definir_usuario_atual(
    estado[:usuario_nao_administrador] || usuario_nao_administrador
  )
end

Given(/^que eu estou logado como Administrador$/) do
  definir_usuario_atual(usuario_administrador)
end

Given(
  /^que existe uma matéria chamada "([^"]+)" pertencente ao departamento "([^"]+)"$/
) do |materia, departamento|
  materia_com_nome(materia, departamento_nome: departamento)
end

Given(
  /^que existe uma turma "([^"]+)" da matéria "([^"]+)" no semestre atual$/
) do |numero, materia|
  turma_da_materia(numero, materia)
end

Given(/^que estou matriculado na turma "([^"]+)"$/) do |turma_nome|
  turma = turma_com_identificador(turma_nome)
  usuario = usuario_atual || usuario_participante
  definir_usuario_atual(usuario)

  ParticipacaoTurma.find_or_create_by!(
    usuario: usuario,
    turma: turma,
    tipo_participacao: :discente
  )
end

Given(/^que não estou matriculado na turma "([^"]+)"$/) do |turma_nome|
  turma = turma_com_identificador(turma_nome)
  usuario = usuario_atual || usuario_participante

  ParticipacaoTurma.where(usuario: usuario, turma: turma).delete_all
end

Given(/^que existe um template chamado "([^"]+)"$/) do |titulo|
  estado[:template_atual] = template_com_titulo(titulo)
end

Given(/^que existe um template cadastrado chamado "([^"]+)"$/) do |titulo|
  estado[:template_atual] = template_com_titulo(titulo)
end

Given(/^que existe um template chamado "([^"]+)" criado por mim$/) do |titulo|
  estado[:template_atual] = template_com_titulo(titulo, adm: adm_atual)
end

Given(
  /^que o template "([^"]+)" possui a questão "([^"]+)"$/
) do |titulo, enunciado|
  template = Template.find_by!(titulo: titulo)
  next if template.questoes.exists?(enunciado: enunciado)

  questao = Questao.create!(enunciado: enunciado, tipo: :discursiva)
  template.utilizacao_questoes.create!(
    questao: questao,
    numero: template.utilizacao_questoes.count + 1
  )
end

Given(/^que não existem templates criados por mim$/) do
  Template.where(adm: adm_atual).destroy_all
end

Given(
  /^que existe um formulário criado a partir do template "([^"]+)"$/
) do |titulo|
  template = Template.find_by!(titulo: titulo)
  turma = turma_com_identificador("Cálculo 1")
  estado[:formulario_anterior] = formulario_para_turma(turma, template: template)
end

Given(
  /^que existe um formulário chamado "([^"]+)" criado a partir do template "([^"]+)"$/
) do |nome, titulo|
  template = Template.find_by!(titulo: titulo)
  turma = turma_com_identificador("Cálculo 1")
  formulario = formulario_para_turma(turma, template: template)

  estado[:formularios_por_nome][nome] = formulario
end

Given(
  /^que existe um formulário chamado "([^"]+)" associado à turma "([^"]+)" da matéria "([^"]+)"$/
) do |nome, turma_numero, materia_nome|
  turma = turma_da_materia(turma_numero, materia_nome)
  adm = usuario_administrador(departamento: turma.departamento.nome).perfil_adm
  formulario = formulario_para_turma(turma, adm: adm)

  estado[:formularios_por_nome][nome] = formulario
end

Given(/^que existe um formulário pendente para a turma "([^"]+)"$/) do |turma_nome|
  turma = turma_com_identificador(turma_nome)
  usuario = usuario_atual || usuario_participante
  definir_usuario_atual(usuario)

  formulario = formulario_para_turma(turma)
  participacao = ParticipacaoTurma.find_by(usuario: usuario, turma: turma)

  if participacao.present?
    Avaliacao.find_or_create_by!(
      formulario: formulario,
      participacao_turma: participacao
    )
  end

  estado[:formulario_atual] = formulario
end

Given(/^que existe um formulário com respostas para a turma "([^"]+)"$/) do |turma_nome|
  turma = turma_com_identificador(turma_nome)
  participante = usuario_participante(
    nome: "Participante #{turma_nome}",
    email: "#{turma_nome.parameterize}@unb.br",
    matricula: "MAT#{Usuario.count + 1}"
  )
  participacao = ParticipacaoTurma.create!(
    usuario: participante,
    turma: turma,
    tipo_participacao: :discente
  )
  formulario = formulario_para_turma(turma)
  avaliacao = Avaliacao.create!(
    formulario: formulario,
    participacao_turma: participacao,
    respondido_em: Time.current
  )
  questao = formulario.template.questoes.first
  Resposta.create!(
    avaliacao: avaliacao,
    questao: questao,
    texto_attributes: { texto: "Resposta de exemplo" }
  )

  estado[:formulario_atual] = formulario
end

Given(
  /^que existe um formulário sem respostas para a turma "([^"]+)" do meu departamento$/
) do |turma_nome|
  turma = turma_com_identificador(
    turma_nome,
    departamento_nome: adm_atual.departamento.nome
  )

  estado[:formulario_atual] = formulario_para_turma(turma, adm: adm_atual)
end

Given(/^que não possuo formulários pendentes nas minhas turmas$/) do
  usuario = usuario_atual || usuario_participante
  Avaliacao.joins(:participacao_turma)
    .where(participacoes_turmas: { usuario_id: usuario.id })
    .destroy_all
end

Given(/^que já respondi o formulário da turma "([^"]+)" anteriormente$/) do |turma_nome|
  steps %(
    Dado que estou matriculado na turma "#{turma_nome}"
    E que existe um formulário pendente para a turma "#{turma_nome}"
  )

  Avaliacao.last.marcar_como_respondida!
end

Given(/^que existem as turmas "([^"]+)" e "([^"]+)" cadastradas no semestre atual$/) do |primeira, segunda|
  estado[:turmas_selecionaveis] = [
    turma_com_identificador(primeira),
    turma_com_identificador(segunda)
  ]
end

Given(/^que selecionei o template "([^"]+)"$/) do |titulo|
  estado[:template_selecionado] = template_com_titulo(titulo)
end

Given(/^selecionei a turma "([^"]+)"$/) do |turma_nome|
  estado[:turma_selecionada] = turma_com_identificador(turma_nome)
end

Given(/^que existem formulários criados para o semestre atual$/) do
  turma = turma_com_identificador("Cálculo 1")
  estado[:formulario_atual] = formulario_para_turma(turma)
end

Given(/^que nenhum formulário foi gerado para o semestre vigente$/) do
  Formulario.destroy_all
end

Then(/^devo ver a turma "([^"]+)" da matéria "([^"]+)"$/) do |numero, materia|
  turma = turma_da_materia(numero, materia)

  expect(Turma.do_departamento(adm_atual.departamento)).to include(turma)
end

Then(/^não devo ver a turma "([^"]+)" da matéria "([^"]+)"$/) do |numero, materia|
  turma = turma_da_materia(numero, materia)

  expect(Turma.do_departamento(adm_atual.departamento)).not_to include(turma)
end

Then(/^devo ver o formulário "([^"]+)"$/) do |nome|
  formulario = estado[:formularios_por_nome].fetch(nome)

  expect(Formulario.do_departamento(adm_atual.departamento)).to include(formulario)
end

Then(/^o formulário "([^"]+)" deve continuar existindo$/) do |nome|
  formulario = estado[:formularios_por_nome].fetch(nome)

  expect(Formulario.exists?(formulario.id)).to be(true)
end

Then(
  /^o formulário deve estar associado à turma "([^"]+)" da matéria "([^"]+)"$/
) do |numero, materia|
  turma = turma_da_materia(numero, materia)

  expect(Formulario.exists?(turma: turma)).to be(true)
end

Then(/^o template "([^"]+)" deve continuar existindo$/) do |titulo|
  expect(Template.exists?(titulo: titulo)).to be(true)
end

Then(/^o template não deve ser criado$/) do
  expect(estado[:template_criado]).to be_nil
end

Then(/^nenhum formulário deve ser gerado$/) do
  expect(Formulario.count).to eq(0)
end

Then(/^o formulário não deve ser criado$/) do
  expect(estado[:formulario_criado]).to be_nil
end

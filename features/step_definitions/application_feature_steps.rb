# frozen_string_literal: true

Given(/^estou na página "([^"]+)"$/) do |pagina|
  pendente_por_app_incompleto!("página '#{pagina}'")
end

Given(/^que estou na página de criação de formulários$/) do
  pendente_por_app_incompleto!("criação de formulários")
end

Given(/^que estou na etapa de definição de público-alvo$/) do
  pendente_por_app_incompleto!("definição de público-alvo")
end

Given(/^que estou na página de resposta do formulário da turma "([^"]+)"$/) do |turma|
  pendente_por_app_incompleto!("resposta de formulário da turma #{turma}")
end

When(/^eu acesso a página de avaliações pendentes$/) do
  pendente_por_app_incompleto!("listagem de avaliações pendentes")
end

When(/^eu acesso a página de criação de formulário$/) do
  pendente_por_app_incompleto!("criação de formulário")
end

When(/^eu acesso a página de formulários criados$/) do
  pendente_por_app_incompleto!("listagem de formulários")
end

When(/^eu acesso a página de gerenciamento de turmas$/) do
  pendente_por_app_incompleto!("gerenciamento de turmas")
end

When(/^eu acesso a página de relatórios do meu departamento$/) do
  pendente_por_app_incompleto!("relatórios departamentais")
end

When(/^eu acesso o painel de gerenciamento de formulários$/) do
  pendente_por_app_incompleto!("painel de gerenciamento de formulários")
end

When(/^eu acesso o link de redefinição do e-mail dentro do prazo de validade$/) do
  pendente_por_app_incompleto!("recuperação de senha")
end

When(/^eu tento acessar o link de redefinição contido no e-mail$/) do
  pendente_por_app_incompleto!("recuperação de senha")
end

When(/^eu tento acessar a página de resposta do formulário da turma "([^"]+)"$/) do |turma|
  pendente_por_app_incompleto!("resposta de formulário da turma #{turma}")
end

When(/^eu tento acessar a rota de exportação de resultados em CSV$/) do
  pendente_por_app_incompleto!("exportação CSV")
end

When(/^eu tento acessar o formulário "([^"]+)"$/) do |formulario|
  pendente_por_app_incompleto!("acesso ao formulário #{formulario}")
end

When(/^eu tento exportar os resultados do formulário "([^"]+)"$/) do |formulario|
  pendente_por_app_incompleto!("exportação CSV do formulário #{formulario}")
end

When(/^eu seleciono o template "([^"]+)"$/) do |titulo|
  estado[:template_selecionado] = Template.find_by!(titulo: titulo)
end

When(/^seleciono o template "([^"]+)"$/) do |titulo|
  estado[:template_selecionado] = Template.find_by!(titulo: titulo)
end

When(/^seleciono as turmas "([^"]+)" e "([^"]+)"$/) do |primeira, segunda|
  estado[:turmas_selecionadas] = [
    turma_com_identificador(primeira),
    turma_com_identificador(segunda)
  ]
end

When(/^seleciono a turma "([^"]+)" da matéria "([^"]+)"$/) do |numero, materia|
  estado[:turma_selecionada] = turma_da_materia(numero, materia)
end

When(/^não seleciono nenhuma turma$/) do
  estado[:turmas_selecionadas] = []
end

When(/^seleciono o público-alvo "([^"]+)"$/) do |publico|
  estado[:publico_alvo] = publico
end

When(/^eu seleciono a opção de público-alvo como "([^"]+)"$/) do |publico|
  estado[:publico_alvo] = publico.downcase
end

When(/^eu não seleciono nem "Docentes" e nem "Discentes"$/) do
  estado[:publico_alvo] = nil
end

When(/^confirmo a criação do formulário$/) do
  turma = estado.fetch(:turma_selecionada)
  template = estado.fetch(:template_selecionado)
  publico = estado.fetch(:publico_alvo, "discentes")

  if turma.departamento_id != adm_atual.departamento_id
    estado[:mensagens] << "não tenho permissão para gerenciar essa turma"
    next
  end

  estado[:formulario_criado] = Formulario.create!(
    adm: adm_atual,
    turma: turma,
    template: template,
    publico_alvo: publico
  )
  estado[:mensagens] << "o formulário foi criado com sucesso"
end

When(/^pressiono o botão "Criar Formulário"$/) do
  steps("Quando confirmo a criação do formulário")
end

When(/^confirmo a publicação do formulário$/) do
  pendente_por_app_incompleto!("publicação de formulário")
end

When(/^eu preencho todas as questões obrigatórias$/) do
  pendente_por_app_incompleto!("preenchimento de avaliação")
end

When(/^eu deixo uma questão obrigatória em branco$/) do
  pendente_por_app_incompleto!("validação de avaliação incompleta")
end

When(/^confirmo o envio da avaliação$/) do
  pendente_por_app_incompleto!("envio de avaliação")
end

When(/^solicito a exportação do formulário da turma "([^"]+)"$/) do |turma|
  pendente_por_app_incompleto!("exportação CSV da turma #{turma}")
end

When(/^eu solicito a exportação do formulário da turma "([^"]+)"$/) do |turma|
  pendente_por_app_incompleto!("exportação CSV da turma #{turma}")
end

Then(/^devo ver o formulário da turma "([^"]+)" na lista$/) do |turma_nome|
  turma = turma_com_identificador(turma_nome)
  formularios = Formulario.joins(turma: :materia).where(turmas: { id: turma.id })

  expect(formularios).to exist
end

Then(/^não devo ver o formulário da turma "([^"]+)" na lista$/) do |turma_nome|
  turma = turma_com_identificador(turma_nome)
  usuario = usuario_atual
  formularios = Formulario.joins(turma: :participacoes_turma)
    .where(turmas: { id: turma.id })
    .where(participacoes_turmas: { usuario_id: usuario.id })

  expect(formularios).not_to exist
end

Then(/^o status do formulário deve ser "Não respondido"$/) do
  expect(estado[:formulario_atual].avaliacoes.pendentes).to exist
end

Then(/^o formulário da turma "([^"]+)" não deve mais aparecer na lista de pendentes$/) do |turma|
  pendente_por_app_incompleto!("lista de pendências da turma #{turma}")
end

Then(/^a avaliação não deve ser registrada$/) do
  expect(Avaliacao.respondidas.count).to eq(0)
end

Then(/^o formulário deve ser gerado com sucesso para ambas as turmas$/) do
  pendente_por_app_incompleto!("criação de formulário para múltiplas turmas")
end

Then(/^o formulário deve ficar disponível apenas para os alunos matriculados na turma "([^"]+)"$/) do |turma|
  pendente_por_app_incompleto!("público-alvo discente da turma #{turma}")
end

Then(/^o formulário deve ficar disponível apenas para os professores vinculados à turma "([^"]+)"$/) do |turma|
  pendente_por_app_incompleto!("público-alvo docente da turma #{turma}")
end

Then(/^os docentes da turma não devem ter acesso para responder a este formulário$/) do
  pendente_por_app_incompleto!("restrição de acesso de docentes")
end

Then(/^o formulário não deve ser publicado$/) do
  expect(estado[:formulario_criado]).to be_nil
end

Then(/^eu devo ver uma lista com todos os formulários criados, exibindo o template base, a turma e o público-alvo de cada um$/) do
  pendente_por_app_incompleto!("listagem detalhada de formulários")
end

Then(/^cada formulário listado deve exibir um botão "([^"]+)"$/) do |botao|
  pendente_por_app_incompleto!("botão '#{botao}' na listagem de formulários")
end

Then(/^eu devo ver a listagem vazia$/) do
  expect(Formulario.count).to eq(0)
end

Then(/^a mensagem "([^"]+)" deve ser exibida na tela$/) do |mensagem|
  pendente_por_app_incompleto!("mensagem '#{mensagem}'")
end

Then(/^eu devo ver uma mensagem de erro dizendo "([^"]+)"$/) do |mensagem|
  pendente_por_app_incompleto!("mensagem '#{mensagem}'")
end

Then(/^eu devo ver o alerta "([^"]+)"$/) do |mensagem|
  pendente_por_app_incompleto!("alerta '#{mensagem}'")
end

Then(/^o download do arquivo CSV deve ser iniciado$/) do
  pendente_por_app_incompleto!("download CSV")
end

Then(/^o CSV deve conter os dados esperados das avaliações$/) do
  pendente_por_app_incompleto!("conteúdo CSV de avaliações")
end

Then(/^o arquivo CSV deve conter apenas a linha de cabeçalho$/) do
  pendente_por_app_incompleto!("CSV sem respostas")
end

Then(/^nenhum arquivo CSV deve ser baixado$/) do
  pendente_por_app_incompleto!("bloqueio de download CSV")
end

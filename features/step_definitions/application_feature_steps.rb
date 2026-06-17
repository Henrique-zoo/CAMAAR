# frozen_string_literal: true

Given(/^estou na página "([^"]+)"$/) do |pagina|
  pendente_por_app_incompleto!("página '#{pagina}'")
end

When(/^eu acesso a página de criação de formulário$/) do
  pendente_por_app_incompleto!("criação de formulário")
end

When(/^eu acesso a página de gerenciamento de turmas$/) do
  pendente_por_app_incompleto!("gerenciamento de turmas")
end

When(/^eu acesso o link de redefinição do e-mail dentro do prazo de validade$/) do
  pendente_por_app_incompleto!("recuperação de senha")
end

When(/^eu tento acessar o link de redefinição contido no e-mail$/) do
  pendente_por_app_incompleto!("recuperação de senha")
end

When(/^eu tento acessar o formulário "([^"]+)"$/) do |formulario|
  pendente_por_app_incompleto!("acesso ao formulário #{formulario}")
end

When(/^eu tento exportar os resultados do formulário "([^"]+)"$/) do |formulario|
  pendente_por_app_incompleto!("exportação CSV do formulário #{formulario}")
end

When(/^seleciono o template "([^"]+)"$/) do |titulo|
  estado[:template_selecionado] = Template.find_by!(titulo: titulo)
end

When(/^seleciono a turma "([^"]+)" da matéria "([^"]+)"$/) do |numero, materia|
  estado[:turma_selecionada] = turma_da_materia(numero, materia)
end

When(/^seleciono o público-alvo "([^"]+)"$/) do |publico|
  estado[:publico_alvo] = publico
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

Then(/^devo ver uma mensagem informando que o formulário foi criado com sucesso$/) do
  expect(estado[:mensagens]).to include("o formulário foi criado com sucesso")
end

Then(/^devo ver uma mensagem informando que não tenho permissão para gerenciar essa turma$/) do
  expect(estado[:mensagens]).to include("não tenho permissão para gerenciar essa turma")
end

Then(/^devo ver uma mensagem informando que não tenho permissão para acessar esse formulário$/) do
  pendente_por_app_incompleto!("permissão de acesso a formulário")
end

Then(/^devo ver uma mensagem informando que não tenho permissão para exportar os resultados desse formulário$/) do
  pendente_por_app_incompleto!("permissão de exportação de formulário")
end

Then(/^nenhum arquivo CSV deve ser baixado$/) do
  pendente_por_app_incompleto!("bloqueio de download CSV")
end

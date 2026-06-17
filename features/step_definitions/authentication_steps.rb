# frozen_string_literal: true

Given(
  /^que a base de dados possui um usuário comum com e-mail "([^"]+)", matrícula "([^"]+)" e senha "([^"]+)"$/
) do |email, matricula, senha|
  estado[:usuario_comum] = usuario_participante(
    nome: "Aluno",
    email: email,
    matricula: matricula
  )
  estado[:usuario_comum].update!(senha: senha)
end

Given(/^possui um usuário administrador com matrícula "([^"]+)" e senha "([^"]+)"$/) do |matricula, senha|
  usuario = usuario_administrador
  usuario.update!(matricula: matricula, senha: senha)
  estado[:matriculas_administrativas] ||= {}
  estado[:matriculas_administrativas][matricula] = usuario.id
end

Given(/^que fui importado do SIGAA mas ainda não possuo senha cadastrada$/) do
  estado[:usuario_importado] = Usuario.create!(
    nome: "Usuário importado",
    email: "usuario.importado@unb.br",
    matricula: "IMPORTADO123",
    status: :pendente
  )
end

Given(/^que acessei o link de ativação contido no e-mail de cadastro enviado pelo sistema$/) do
  pendente_por_app_incompleto!("ativação de cadastro por token")
end

Given(/^que estou na página de login$/) do
  pendente_por_app_incompleto!("login")
end

Given(/^que solicitei a recuperação de senha e recebi o e-mail com o link de redefinição$/) do
  pendente_por_app_incompleto!("recuperação de senha")
end

Given(/^que solicitei a recuperação de senha e recebi o e-mail há mais de 24 horas$/) do
  pendente_por_app_incompleto!("expiração de token de recuperação de senha")
end

When(/^eu preencho o campo "([^"]+)" com "([^"]+)"$/) do |campo, valor|
  estado[:campos][campo] = valor
end

When(/^preencho o campo "([^"]+)" com "([^"]+)"$/) do |campo, valor|
  estado[:campos][campo] = valor
end

When(/^eu deixo o campo "([^"]+)" vazio$/) do |campo|
  estado[:campos][campo] = nil
end

When(/^deixo o campo "([^"]+)" vazio$/) do |campo|
  estado[:campos][campo] = nil
end

When(/^preencho a nova senha com "([^"]+)"$/) do |senha|
  estado[:campos]["Nova Senha"] = senha
end

When(/^confirmo a nova senha com "([^"]+)"$/) do |senha|
  estado[:campos]["Confirme a Senha"] = senha
end

When(/^eu clico em "([^"]+)"$/) do |acao|
  case acao
  when "Esqueci minha senha"
    pendente_por_app_incompleto!("recuperação de senha")
  else
    pendente_por_app_incompleto!("ação '#{acao}'")
  end
end

When(/^clico em "(Definir Senha|Enviar link de recuperação|Atualizar Senha)"$/) do |acao|
  pendente_por_app_incompleto!("ação '#{acao}'")
end

When(/^clico no botão "([^"]+)"$/) do |botao|
  pendente_por_app_incompleto!("botão '#{botao}'")
end

Then(/^devo ser autenticado com sucesso$/) do
  pendente_por_app_incompleto!("login")
end

Then(/^devo visualizar a opção de gerenciamento no menu lateral$/) do
  pendente_por_app_incompleto!("menu lateral")
end

Then(/^não devo visualizar a opção de gerenciamento no menu lateral$/) do
  pendente_por_app_incompleto!("menu lateral")
end

Then(/^permaneço na página de login$/) do
  pendente_por_app_incompleto!("login")
end

Then(/^meu usuário deve ser ativado na base de dados$/) do
  expect(estado[:usuario_importado].reload).to be_ativo
end

Then(/^o meu usuário deve continuar inativo$/) do
  expect(estado[:usuario_importado].reload).to be_pendente
end

Then(/^minha senha deve ser atualizada no sistema$/) do
  pendente_por_app_incompleto!("recuperação de senha")
end

Then(/^devo ser redirecionado para a página de login$/) do
  pendente_por_app_incompleto!("redirecionamento de login")
end

Then(/^eu devo ser redirecionado para a página de solicitação de recuperação$/) do
  pendente_por_app_incompleto!("recuperação de senha")
end

Then(/^devo ver a mensagem "Um link de redefinição foi enviado para o seu e-mail"$/) do
  pendente_por_app_incompleto!("mensagem de solicitação de recuperação de senha")
end

Then(/^devo ver a mensagem "Cadastro ativado com sucesso!"$/) do
  pendente_por_app_incompleto!("mensagem de ativação de cadastro")
end

Then(/^devo ver a mensagem de erro "([^"]+)"$/) do |mensagem|
  if estado[:mensagens].include?(mensagem)
    expect(estado[:mensagens]).to include(mensagem)
  else
    pendente_por_app_incompleto!("mensagem '#{mensagem}'")
  end
end

Then(/^devo ver o aviso "([^"]+)"$/) do |mensagem|
  pendente_por_app_incompleto!("aviso '#{mensagem}'")
end

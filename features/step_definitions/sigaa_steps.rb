# frozen_string_literal: true

Given(/^que o sistema não possui nenhuma turma cadastrada$/) do
  Avaliacao.delete_all
  Formulario.delete_all
  ParticipacaoTurma.delete_all
  Turma.delete_all
end

Given(/^que o sistema não possui nenhum usuário cadastrado$/) do
  Avaliacao.delete_all
  ParticipacaoTurma.delete_all
  PerfilAdm.delete_all
  PerfilDiscente.delete_all
  PerfilDocente.delete_all
  Usuario.delete_all
end

Given(/^que o sistema possui a turma "([^"]+)" \(([^)]+)\) cadastrada$/) do |nome, codigo|
  materia = materia_com_nome(
    nome,
    departamento_nome: "Departamento de Ciência da Computação",
    codigo: codigo
  )

  Turma.find_or_create_by!(
    materia: materia,
    ano: Time.zone.today.year,
    semestre: :primeiro,
    numero: 1
  )
end

Given(/^que o sistema não possui o usuário "([^"]+)" \(([^)]+)\) cadastrado$/) do |_nome, matricula|
  usuario = Usuario.find_by(matricula: matricula)
  usuario&.destroy!
end

Given(/^que o SIGAA contém a turma "([^"]+)" \(([^)]+)\)$/) do |nome, codigo|
  estado[:sigaa][:turmas] << { nome: nome, codigo: codigo }
end

Given(
  /^que o SIGAA contém as turmas "([^"]+)" \(([^)]+)\), "([^"]+)" \(([^)]+)\) e "([^"]+)" \(([^)]+)\)$/
) do |nome1, codigo1, nome2, codigo2, nome3, codigo3|
  estado[:sigaa][:turmas].concat(
    [
      { nome: nome1, codigo: codigo1 },
      { nome: nome2, codigo: codigo2 },
      { nome: nome3, codigo: codigo3 }
    ]
  )
end

Given(/^esta turma contém o participante "([^"]+)" \(([^)]+)\)$/) do |nome, matricula|
  estado[:sigaa][:participantes] << {
    nome: nome,
    matricula: matricula,
    email: "#{matricula}@unb.br"
  }
end

Given(
  /^que o SIGAA contém o participante "([^"]+)" \(([^)]+)\) na turma "([^"]+)" \(([^)]+)\)$/
) do |nome, matricula, turma, codigo|
  estado[:sigaa][:participantes] << {
    nome: nome,
    matricula: matricula,
    turma: turma,
    codigo: codigo,
    email: "#{matricula}@unb.br"
  }
end

Given(
  /^que o SIGAA contém o participante "([^"]+)" \(([^)]+)\) na turma "([^"]+)" \(([^)]+)\) sem e-mail cadastrado$/
) do |nome, matricula, turma, codigo|
  estado[:sigaa][:participantes] << {
    nome: nome,
    matricula: matricula,
    turma: turma,
    codigo: codigo,
    email: nil
  }
end

Given(/^que o SIGAA retorna um arquivo JSON inválido$/) do
  estado[:sigaa][:erro] = :json_invalido
end

Given(/^que o SIGAA está indisponível$/) do
  estado[:sigaa][:erro] = :indisponivel
end

Given(
  /^que o usuário "([^"]+)" \(([^)]+)\) já existe no sistema com o e-mail "([^"]+)"$/
) do |nome, matricula, email|
  usuario_participante(nome: nome, email: email, matricula: matricula)
end

Given(
  /^que o usuário "([^"]+)" \(([^)]+)\) já existe no sistema com o nome "([^"]+)"$/
) do |_nome_original, matricula, nome|
  usuario_participante(
    nome: nome,
    email: "#{matricula}@unb.br",
    matricula: matricula
  )
end

Given(
  /^que o usuário "([^"]+)" \(([^)]+)\) já existe no sistema com o e-mail "([^"]+)" e o nome "([^"]+)"$/
) do |_nome_original, matricula, email, nome|
  usuario_participante(nome: nome, email: email, matricula: matricula)
end

Given(
  /^a fonte de dados externa indica que o e-mail de "([^"]+)" agora é "([^"]+)"$/
) do |matricula, email|
  estado[:sigaa][:atualizacoes][matricula] ||= {}
  estado[:sigaa][:atualizacoes][matricula][:email] = email
end

Given(
  /^a fonte de dados externa indica que o nome de "([^"]+)" agora é "([^"]+)"$/
) do |matricula, nome|
  estado[:sigaa][:atualizacoes][matricula] ||= {}
  estado[:sigaa][:atualizacoes][matricula][:nome] = nome
end

Given(
  /^a fonte de dados externa indica que o e-mail de "([^"]+)" agora é "([^"]+)" e o nome agora é "([^"]+)"$/
) do |matricula, email, nome|
  estado[:sigaa][:atualizacoes][matricula] = { email: email, nome: nome }
end

When(/^eu clico no botão "Importar dados"$/) do
  pendente_por_app_incompleto!("importação SIGAA")
end

When(/^eu clico no botão "Solicitar definição de senha"$/) do
  pendente_por_app_incompleto!("solicitação de definição de senha via SIGAA")
end

Then(/^a turma "([^"]+)" \(([^)]+)\) deve ser cadastrada no sistema$/) do |nome, codigo|
  expect(Materia.exists?(nome: nome, codigo: codigo)).to be(true)
end

Then(/^o usuário "([^"]+)" \(([^)]+)\) deve ser cadastrado no sistema$/) do |_nome, matricula|
  expect(Usuario.exists?(matricula: matricula)).to be(true)
end

Then(/^o usuário "([^"]+)" deve estar matriculado na turma "([^"]+)"$/) do |nome, turma|
  usuario = Usuario.find_by!(nome: nome)
  materia = Materia.find_by!(nome: turma)

  expect(usuario.turmas.joins(:materia).where(materias: { id: materia.id })).to exist
end

Then(/^as 3 matérias devem ser cadastradas no sistema$/) do
  expect(Materia.count).to eq(3)
end

Then(/^as 3 turmas devem ser cadastradas no sistema$/) do
  expect(Turma.count).to eq(3)
end

Then(/^nenhuma matéria ou turma deve ser duplicada$/) do
  expect(Materia.distinct.count(:codigo)).to eq(Materia.count)
  expect(Turma.distinct.count(:id)).to eq(Turma.count)
end

Then(/^nenhuma nova turma deve ser cadastrada no sistema$/) do
  expect(Turma.count).to eq(0)
end

Then(/^nenhum novo usuário deve ser cadastrado no sistema$/) do
  expect(Usuario.count).to eq(0)
end

Then(/^nenhuma turma existente deve ser alterada no sistema$/) do
  pendente_por_app_incompleto!("auditoria de sincronização de turmas")
end

Then(/^nenhum usuário existente deve ser alterado no sistema$/) do
  pendente_por_app_incompleto!("auditoria de sincronização de usuários")
end

Then(/^nenhum usuário duplicado deve ser criado$/) do
  expect(Usuario.distinct.count(:email)).to eq(Usuario.count)
end

Then(/^o e-mail do usuário "([^"]+)" deve ser atualizado para "([^"]+)"$/) do |matricula, email|
  usuario = Usuario.find_by!(matricula: matricula)

  expect(usuario.email).to eq(email)
end

Then(/^o nome do usuário "([^"]+)" deve ser atualizado para "([^"]+)"$/) do |matricula, nome|
  usuario = Usuario.find_by!(matricula: matricula)

  expect(usuario.nome).to eq(nome)
end

Then(/^o usuário "([^"]+)" \(([^)]+)\) deve estar pendente de definição de senha$/) do |_nome, matricula|
  usuario = Usuario.find_by!(matricula: matricula)

  expect(usuario).to be_pendente
end

Then(/^o usuário "([^"]+)" \(([^)]+)\) não deve possuir senha definida$/) do |_nome, matricula|
  usuario = Usuario.find_by!(matricula: matricula)

  expect(usuario.senha_digest).to be_blank
end

Then(/^o usuário "([^"]+)" \(([^)]+)\) não deve ser cadastrado no sistema$/) do |_nome, matricula|
  expect(Usuario.exists?(matricula: matricula)).to be(false)
end

Then(/^nenhuma solicitação de definição de senha deve ser enviada$/) do
  pendente_por_app_incompleto!("envio de solicitação de definição de senha")
end

Then(/^eu devo ver a mensagem de sucesso "([^"]+)"$/) do |mensagem|
  if estado[:mensagens].include?(mensagem)
    expect(estado[:mensagens]).to include(mensagem)
  else
    pendente_por_app_incompleto!("mensagem '#{mensagem}'")
  end
end

Then(/^eu devo ver a mensagem de erro "([^"]+)"$/) do |mensagem|
  if estado[:mensagens].include?(mensagem)
    expect(estado[:mensagens]).to include(mensagem)
  else
    pendente_por_app_incompleto!("mensagem '#{mensagem}'")
  end
end

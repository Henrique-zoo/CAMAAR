# features/step_definitions/avaliacoes_steps.rb

Before do
  Avaliacao.destroy_all
  ParticipacaoTurma.destroy_all
  Formulario.destroy_all
  Turma.destroy_all
  Materia.destroy_all
  Departamento.destroy_all
  PerfilDiscente.destroy_all
  PerfilAdm.destroy_all
  Usuario.destroy_all
end

def criar_participacao_com_perfil(usuario, turma, tipo)
  if tipo == :discente
    PerfilDiscente.find_or_create_by!(usuario: usuario) do |p|
      p.matricula = "MAT#{rand(10000..99999)}"
    end
  end

  ParticipacaoTurma.find_or_create_by!(usuario: usuario, turma: turma) do |p|
    p.tipo_participacao = tipo
  end
end

Dado('que existe um usuário participante cadastrado no sistema') do
  @email_teste = "joao#{rand(10000)}@teste.com"
  @usuario = Usuario.create!(
    nome: 'João Participante',
    email: @email_teste,
    senha: 'password123',
    status: :ativo
  )
  PerfilDiscente.create!(usuario: @usuario, matricula: "MAT#{rand(10000..99999)}")
end

Dado('que estou autenticado como participante') do
  # allow_any_instance_of agora funciona via features/support/rspec_mocks.rb
  allow_any_instance_of(ApplicationController)
    .to receive(:current_usuario)
    .and_return(@usuario)
end

Dado('que estou matriculado na turma {string}') do |nome_turma|
  depto   = Departamento.find_or_create_by!(nome: 'Departamento Geral')
  materia = Materia.find_or_create_by!(nome: nome_turma, departamento: depto) do |m|
    m.codigo = "COD#{rand(1000..9999)}"
  end
  @turma = Turma.find_or_create_by!(materia: materia, ano: 2026, semestre: :primeiro) do |t|
    t.numero = rand(1..100)
  end

  criar_participacao_com_perfil(@usuario, @turma, :discente)
end

Dado('que existe um formulário pendente para a turma {string}') do |nome_turma|
  depto   = Departamento.find_or_create_by!(nome: 'Departamento Geral')
  materia = Materia.find_or_create_by!(nome: nome_turma, departamento: depto) do |m|
    m.codigo = "COD#{rand(1000..9999)}"
  end

  # Reutiliza @turma se já foi criada para esse nome (cenário matriculado)
  # ou cria uma nova turma isolada (cenário sem matrícula)
  turma = @turma || Turma.find_or_create_by!(materia: materia, ano: 2026, semestre: :primeiro) do |t|
    t.numero = rand(1..100)
  end

  adm      = Usuario.create!(nome: 'Adm', email: "adm#{rand(10000)}@t.com", senha: 'password123', status: :ativo)
  perf_adm = PerfilAdm.create!(usuario: adm, departamento: depto)

  @formulario = Formulario.create!(adm: perf_adm, turma: turma, publico_alvo: :discentes)

  # Cria a avaliação para o @usuario (participante do teste), não para um fantasma
  participacao = ParticipacaoTurma.find_by(usuario: @usuario, turma: turma)
  Avaliacao.create!(formulario: @formulario, participacao_turma: participacao) if participacao
end

Quando('eu acesso a página de avaliações pendentes') do
  visit pendentes_avaliacoes_path
end

Então('devo ver o formulário da turma {string} na lista') do |nome_turma|
  expect(page).to have_content(nome_turma)
end

Então('o status do formulário deve ser {string}') do |status|
  expect(page).to have_content(status)
end

Dado('que não possuo formulários pendentes nas minhas turmas') do
  # O Before já limpou o banco; nenhuma avaliação existe. Nada a fazer.
end

Então('devo ver uma mensagem informando que nenhum formulário pendente foi encontrado') do
  expect(page).to have_content('Nenhum formulário pendente foi encontrado.')
end

Dado('que não estou matriculado na turma {string}') do |_nome_turma|
  # Intencionalmente vazio: não criamos participação para @usuario nessa turma.
end

Então('não devo ver o formulário da turma {string} na lista') do |nome_turma|
  expect(page).not_to have_content(nome_turma)
end
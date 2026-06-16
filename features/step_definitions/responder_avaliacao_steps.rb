# features/step_definitions/responder_avaliacao_steps.rb
# Steps exclusivos da HU14 – Responder questionário da turma
# Steps compartilhados (usuário, autenticação) vêm do avaliacoes_steps.rb

def criar_contexto_formulario_com_questoes(nome_turma)
  depto   = Departamento.find_or_create_by!(nome: 'Departamento Geral')
  materia = Materia.find_or_create_by!(nome: nome_turma, departamento: depto) do |m|
    m.codigo = "COD#{rand(1000..9999)}"
  end

  @turma = Turma.find_or_create_by!(materia: materia, ano: 2026, semestre: :primeiro) do |t|
    t.numero = rand(1..100)
  end

  adm      = Usuario.create!(nome: 'Adm', email: "adm#{rand(10000)}@t.com",
                              senha: 'password123', status: :ativo)
  perf_adm = PerfilAdm.create!(usuario: adm, departamento: depto)

  # Questão discursiva
  @questao_discursiva = Questao.create!(
    enunciado: 'Como você avalia a turma?',
    tipo: :discursiva
  )

  # Questão objetiva com opções via nested attributes
  @questao_objetiva = Questao.create!(
    enunciado: 'Qual nota você dá?',
    tipo: :objetiva,
    opcoes_attributes: [
      { numero: 1, texto: 'Ótimo' },
      { numero: 2, texto: 'Ruim'  }
    ]
  )

  # Template criado já com questões via nested attributes
  template = Template.create!(
    adm: perf_adm,
    titulo: "Template #{rand(1000)}",
    utilizacao_questoes_attributes: [
      { questao_id: @questao_discursiva.id, numero: 1 },
      { questao_id: @questao_objetiva.id,   numero: 2 }
    ]
  )

  # Recarrega para garantir associações atualizadas
  @questao_discursiva.reload
  @questao_objetiva.reload

  @formulario = Formulario.create!(
    adm: perf_adm,
    turma: @turma,
    publico_alvo: :discentes,
    template: template
  )

  criar_participacao_com_perfil(@usuario, @turma, :discente)

  participacao = ParticipacaoTurma.find_by!(usuario: @usuario, turma: @turma)
  @avaliacao   = Avaliacao.create!(formulario: @formulario, participacao_turma: participacao)
end

# -------------------------------------------------------
# Dado
# -------------------------------------------------------

Dado('que estou na página de resposta do formulário da turma {string}') do |nome_turma|
  criar_contexto_formulario_com_questoes(nome_turma)
  visit responder_avaliacao_path(@avaliacao)
end

Dado('que já respondi o formulário da turma {string} anteriormente') do |nome_turma|
  criar_contexto_formulario_com_questoes(nome_turma)
  @avaliacao.marcar_como_respondida!
end

# -------------------------------------------------------
# Quando
# -------------------------------------------------------

Quando('eu preencho todas as questões obrigatórias') do
  # Preenche a questão discursiva
  fill_in "respostas[#{@questao_discursiva.id}][texto]", with: 'Achei a turma muito boa.'

  # Seleciona a primeira opção da questão objetiva usando o texto da label
  primeira_opcao = @questao_objetiva.opcoes.ordenadas.first
  within "#questao-#{@questao_objetiva.id}" do
    choose primeira_opcao.texto
  end
end

Quando('eu deixo uma questão obrigatória em branco') do
  fill_in "respostas[#{@questao_discursiva.id}][texto]", with: 'Resposta parcial.'
  # questão objetiva intencionalmente deixada em branco
end

Quando('confirmo o envio da avaliação') do
  click_button 'Confirmar envio'
end

Quando('eu tento acessar a página de resposta do formulário da turma {string}') do |_nome_turma|
  visit responder_avaliacao_path(@avaliacao)
end

# -------------------------------------------------------
# Então
# -------------------------------------------------------

Então('devo ver uma mensagem informando que a avaliação foi registrada com sucesso') do
  expect(page).to have_content('Avaliação registrada com sucesso.')
end

Então('o formulário da turma {string} não deve mais aparecer na lista de pendentes') do |nome_turma|
  expect(page).not_to have_content(nome_turma)
end

Então('devo ver uma mensagem informando que todas as questões obrigatórias devem ser preenchidas') do
  expect(page).to have_content('Todas as questões obrigatórias devem ser preenchidas.')
end

Então('a avaliação não deve ser registrada') do
  @avaliacao.reload
  expect(@avaliacao.respondida?).to be false
end

Então('devo ver uma mensagem informando que esta avaliação já foi respondida') do
  expect(page).to have_content('Esta avaliação já foi respondida.')
end
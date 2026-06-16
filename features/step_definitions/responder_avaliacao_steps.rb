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

  @questao_discursiva = Questao.create!(
    enunciado: 'Como você avalia a turma?',
    tipo: :discursiva
  )

  @questao_objetiva = Questao.create!(
    enunciado: 'Qual nota você dá?',
    tipo: :objetiva
  )
  Opcao.create!(questao: @questao_objetiva, numero: 1, texto: 'Ótimo')
  Opcao.create!(questao: @questao_objetiva, numero: 2, texto: 'Ruim')

  template = Template.create!(adm: perf_adm, titulo: "Template #{rand(1000)}")
  UtilizacaoQuestao.create!(template: template, questao: @questao_discursiva, numero: 1)
  UtilizacaoQuestao.create!(template: template, questao: @questao_objetiva,   numero: 2)

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

Dado('que estou na página de resposta do formulário da turma {string}') do |nome_turma|
  criar_contexto_formulario_com_questoes(nome_turma)
  visit responder_avaliacao_path(@avaliacao)
end

Dado('que já respondi o formulário da turma {string} anteriormente') do |nome_turma|
  criar_contexto_formulario_com_questoes(nome_turma)
  @avaliacao.marcar_como_respondida!
end

Quando('eu preencho todas as questões obrigatórias') do
  find("textarea[name='respostas[#{@questao_discursiva.id}][texto]']")
    .set('Achei a turma muito boa.')

  primeira_opcao = @questao_objetiva.opcoes.ordenadas.first
  find("input[name='respostas[#{@questao_objetiva.id}][opcao_id]'][value='#{primeira_opcao.id}']")
    .set(true)
end

Quando('eu deixo uma questão obrigatória em branco') do
  find("textarea[name='respostas[#{@questao_discursiva.id}][texto]']")
    .set('Resposta parcial.')
  # questão objetiva intencionalmente deixada em branco
end

Quando('confirmo o envio da avaliação') do
  click_button 'Confirmar envio'
end

Quando('eu tento acessar a página de resposta do formulário da turma {string}') do |_nome_turma|
  visit responder_avaliacao_path(@avaliacao)
end

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

Dado("que existe um template cadastrado chamado {string}") do |titulo|
  @admin ||= criar_administrador
  @template = criar_template_com_questoes(titulo: titulo)
end

Dado("que existem as turmas {string} e {string} cadastradas no semestre atual") do |nome_turma_a, nome_turma_b|
  @turma_a = criar_turma_do_nome_exibicao(nome_turma_a)
  @turma_b = criar_turma_do_nome_exibicao(nome_turma_b)
end

Dado("que estou na página de criação de formulários") do
  visit new_formulario_path
end

Dado("que selecionei o template {string}") do |titulo|
  @admin ||= criar_administrador
  @template = criar_template_com_questoes(titulo: titulo)
end

Dado("selecionei a turma {string}") do |nome_turma|
  @turma = criar_turma_do_nome_exibicao(nome_turma)
  preparar_sessao_formulario(template: @template, turmas: [ @turma ])
end

Dado("que estou na etapa de definição de público-alvo") do
  visit publicar_formularios_path
end

Quando("eu seleciono o template {string}") do |titulo|
  select titulo, from: "template_id"
end

Quando("seleciono as turmas {string} e {string}") do |nome_turma_a, nome_turma_b|
  check nome_turma_a
  check nome_turma_b
end

Quando("não seleciono nenhuma turma") do
  page.all('input[name="turma_ids[]"]').each do |checkbox|
    checkbox.set(false) if checkbox.checked?
  end
end

Quando("clico em {string}") do |botao|
  click_button botao
end

Quando("seleciono a opção de público-alvo como {string}") do |publico_alvo|
  choose publico_alvo, allow_label_click: true
end

Quando("eu seleciono a opção de público-alvo como {string}") do |publico_alvo|
  choose publico_alvo, allow_label_click: true
end

Quando("eu não seleciono nem {string} e nem {string}") do |_, _|
  page.all('input[name="publico_alvo"]').each do |radio|
    radio.set(false) if radio.checked?
  end
end

Quando("confirmo a publicação do formulário") do
  click_button "Confirmar Publicação"
end

Então("o formulário deve ser gerado com sucesso para ambas as turmas") do
  expect(Formulario.count).to eq(2)

  formulario_a = @turma_a.reload.formularios.sole
  formulario_b = @turma_b.reload.formularios.sole

  expect(formulario_a).to be_present
  expect(formulario_b).to be_present
  expect(formulario_a.template).to eq(@template)
  expect(formulario_b.template).to eq(@template)

  questoes_template = questoes_ordenadas_do_template(@template)

  [ formulario_a, formulario_b ].each do |formulario|
    questoes_formulario = formulario.questoes.order(:id)
    expect(questoes_formulario.count).to eq(questoes_template.count)
    expect(questoes_formulario.pluck(:enunciado)).to eq(questoes_template.map(&:enunciado))
  end
end

Então("devo ver a mensagem {string}") do |mensagem|
  expect(page).to have_content(mensagem)
end

Então("eu devo ver uma mensagem de erro dizendo {string}") do |mensagem|
  expect(page).to have_content(mensagem)
end

Então("eu devo ver o alerta {string}") do |mensagem|
  expect(page).to have_content(mensagem)
end

Então("nenhum formulário deve ser gerado") do
  expect(Formulario.count).to eq(0)
end

Então("o formulário não deve ser publicado") do
  expect(Formulario.count).to eq(0)
end

Então("o formulário deve ficar disponível apenas para os alunos matriculados na turma {string}") do |nome_turma|
  turma = turma_por_referencia(nome_turma)
  formulario = turma.reload.formularios.sole
  expect(formulario.publico_alvo).to eq("discentes")

  discente = criar_participante
  criar_participacao(usuario: discente, turma: turma, tipo_participacao: :discente)
  formulario.criar_avaliacoes_pendentes!

  login_como(discente)
  visit avaliacoes_pendentes_path
  expect(page).to have_content(turma.nome_exibicao)
end

Então("os docentes da turma não devem ter acesso para responder a este formulário") do
  turma = @turma || turma_por_referencia("Estrutura de Dados - Turma C")
  docente = criar_participante(tipo: :docente, departamento: turma.departamento)
  criar_participacao(usuario: docente, turma: turma, tipo_participacao: :docente)

  login_como(docente)
  visit avaliacoes_pendentes_path
  expect(page).not_to have_content(@template.titulo)
end

Então("o formulário deve ficar disponível apenas para os professores vinculados à turma {string}") do |nome_turma|
  turma = turma_por_referencia(nome_turma)
  formulario = turma.reload.formularios.sole
  expect(formulario.publico_alvo).to eq("docentes")

  docente = criar_participante(tipo: :docente, departamento: turma.departamento)
  criar_participacao(usuario: docente, turma: turma, tipo_participacao: :docente)
  formulario.criar_avaliacoes_pendentes!

  login_como(docente)
  visit avaliacoes_pendentes_path
  expect(page).to have_content(turma.nome_exibicao)
end

def criar_turma_do_nome_exibicao(nome_exibicao)
  materia_nome, codigo = nome_exibicao.split(" - Turma ", 2)
  criar_turma(nome_materia: materia_nome, numero: Turma.numero_de_codigo_exibicao(codigo))
end

def turma_por_referencia(nome)
  return @turma if @turma && nome.include?(@turma.materia.nome)

  if nome.include?(" - Turma ")
    criar_turma_do_nome_exibicao(nome)
  else
    Turma.joins(:materia).find_by!(materias: { nome: nome })
  end
end

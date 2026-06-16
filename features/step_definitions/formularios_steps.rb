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

Então("o formulário deve ser gerado com sucesso para ambas as turmas") do
  expect(Formulario.count).to eq(2)

  formulario_a = @turma_a.reload.formularios.sole
  formulario_b = @turma_b.reload.formularios.sole

  expect(formulario_a).to be_present
  expect(formulario_b).to be_present
  expect(formulario_a.template).to eq(@template)
  expect(formulario_b.template).to eq(@template)

  questoes_template = questoes_ordenadas_do_template(@template)

  [formulario_a, formulario_b].each do |formulario|
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

Então("nenhum formulário deve ser gerado") do
  expect(Formulario.count).to eq(0)
end

def criar_turma_do_nome_exibicao(nome_exibicao)
  materia_nome, codigo = nome_exibicao.split(" - Turma ", 2)
  criar_turma(nome_materia: materia_nome, numero: Turma.numero_de_codigo_exibicao(codigo))
end

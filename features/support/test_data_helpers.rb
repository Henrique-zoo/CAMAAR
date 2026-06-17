module TestDataHelpers
  def criar_administrador(**attrs)
    departamento = attrs[:departamento] || Departamento.create!(nome: "DCC #{SecureRandom.hex(2)}")
    @departamento = departamento
    defaults = {
      nome: "Administrador",
      email: "#{SecureRandom.hex(4)}@example.com",
      status: :ativo,
      senha: "senha12345"
    }
    usuario = Usuario.create!(defaults.merge(attrs.except(:departamento)))
    PerfilAdm.create!(usuario: usuario, departamento: departamento)
    usuario
  end

  def criar_template_com_questoes(titulo:, questoes: nil)
    template = Template.new(
      titulo: titulo,
      descricao: "Template de teste",
      adm: @admin.perfil_adm,
      criado_em: Time.current
    )

    (questoes || questoes_padrao).each_with_index do |questao_attrs, index|
      attrs = questao_attrs.dup
      opcoes = attrs.delete(:opcoes)
      numero = attrs.delete(:numero) || attrs.delete(:posicao) || (index + 1)
      attrs.delete(:obrigatoria)

      questao = Questao.new(attrs)

      Array(opcoes).each_with_index do |texto, opcao_index|
        questao.opcoes.build(numero: opcao_index + 1, texto: texto)
      end if opcoes.present?

      questao.save!

      template.utilizacao_questoes.build(questao: questao, numero: numero)
    end

    template.save!
    template.utilizacao_questoes.each(&:save!)
    template
  end

  def criar_turma(nome_materia:, numero:, semestre: Turma.semestre_atual, ano: Date.current.year)
    departamento = @departamento || @admin&.perfil_adm&.departamento ||
      Departamento.create!(nome: "DCC #{SecureRandom.hex(2)}")
    materia = Materia.find_or_create_by!(codigo: nome_materia.parameterize.upcase) do |record|
      record.nome = nome_materia
      record.departamento = departamento
    end

    Turma.create!(
      materia: materia,
      numero: numero,
      semestre: semestre,
      ano: ano
    )
  end

  def login_como(usuario)
    allow_any_instance_of(ApplicationController).to receive(:current_usuario).and_return(usuario)
  end

  def questoes_ordenadas_do_template(template)
    template.utilizacao_questoes.raizes.ordenadas.includes(:questao).map(&:questao)
  end

  private

  def questoes_padrao
    [
      {
        enunciado: "Como você avalia a disciplina?",
        tipo: :discursiva
      }
    ]
  end
end

World(TestDataHelpers)

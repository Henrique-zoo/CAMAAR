module TestBuilders
  def create_admin_usuario(**attrs)
    defaults = {
      nome: "Administrador",
      matricula: SecureRandom.hex(4),
      status: "ativo"
    }
    usuario = Usuario.create!(defaults.merge(attrs.except(:departamento)))
    PerfilAdm.create!(usuario: usuario, departamento: attrs[:departamento])
    usuario
  end

  def create_usuario(**attrs)
    defaults = {
      nome: "Usuário",
      matricula: SecureRandom.hex(4),
      status: "ativo"
    }
    Usuario.create!(defaults.merge(attrs))
  end

  def create_template_with_questoes(titulo:, perfil_adm: nil, questoes: nil)
    perfil_adm ||= create_admin_usuario.perfil_adm
    template = Template.create!(nome: titulo, descricao: "Descrição de teste", perfil_adm: perfil_adm)

    (questoes || default_questoes).each do |questao_attrs|
      attrs = questao_attrs.dup
      opcoes = attrs.delete(:opcoes)
      questao = template.questoes.create!(attrs)
      Array(opcoes).each { |texto| questao.opcoes.create!(texto: texto) } if opcoes.present?
    end

    template
  end

  def create_turma(nome_materia:, codigo_turma:, semestre: Turma.semestre_atual)
    materia = Materia.create!(
      nome: nome_materia,
      codigo: "#{nome_materia.parameterize}-#{SecureRandom.hex(2)}"
    )

    Turma.create!(
      materia: materia,
      codigo_turma: codigo_turma,
      semestre: semestre
    )
  end

  private

  def default_questoes
    [
      {
        enunciado: "Como você avalia a disciplina?",
        tipo: :discursiva,
        posicao: 1,
        obrigatoria: true
      },
      {
        enunciado: "Nota geral",
        tipo: :objetiva,
        posicao: 2,
        obrigatoria: true,
        opcoes: %w[Ruim Regular Boa Excelente]
      }
    ]
  end
end

RSpec.configure do |config|
  config.include TestBuilders
end

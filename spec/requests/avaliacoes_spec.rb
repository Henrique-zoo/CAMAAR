# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Avaliacoes", type: :request do
  let(:departamento) { Departamento.create!(nome: "DCC #{SecureRandom.hex(2)}") }
  let(:admin) { create_admin_usuario(departamento: departamento) }
  let(:turma) { create_turma(nome_materia: "Cálculo 1", numero: 1, departamento: departamento) }
  let(:template) { create_template_with_questoes(titulo: "Avaliação Geral", adm: admin.perfil_adm) }

  describe "GET /avaliacoes/pendentes" do
    it "exibe pendências apenas para participantes do público-alvo correto" do
      docente = create_usuario(nome: "Docente")
      discente = create_usuario(nome: "Discente")
      create_participacao(usuario: docente, turma: turma, tipo_participacao: :docente)
      create_participacao(usuario: discente, turma: turma, tipo_participacao: :discente)

      create_formulario(
        turma: turma,
        adm: admin.perfil_adm,
        template: template,
        publico_alvo: :discentes,
        criar_avaliacoes: true
      )

      sign_in_as(discente)
      get avaliacoes_pendentes_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(turma.nome_exibicao)
      expect(response.body).to include("Não respondido")

      sign_in_as(docente)
      get avaliacoes_pendentes_path

      expect(response.body).not_to include(template.titulo)
      expect(response.body).to include("Nenhum formulário pendente foi encontrado")
    end

    it "não exibe pendências de turmas em que o usuário não participa" do
      participante = create_usuario
      outro_usuario = create_usuario
      create_participacao(usuario: participante, turma: turma, tipo_participacao: :discente)

      outra_turma = create_turma(nome_materia: "Estrutura de Dados", numero: 1, departamento: departamento)
      create_participacao(usuario: outro_usuario, turma: outra_turma, tipo_participacao: :discente)
      create_formulario(
        turma: outra_turma,
        adm: admin.perfil_adm,
        template: template,
        publico_alvo: :discentes,
        criar_avaliacoes: true
      )

      sign_in_as(participante)
      get avaliacoes_pendentes_path

      expect(response.body).not_to include(outra_turma.nome_exibicao)
      expect(response.body).to include("Nenhum formulário pendente foi encontrado")
    end

    it "redireciona usuário não autenticado" do
      get avaliacoes_pendentes_path

      expect(response).to redirect_to(login_path)
    end
  end
end

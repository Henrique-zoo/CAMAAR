require "rails_helper"

RSpec.describe "Formularios", type: :request do
  let(:departamento) { Departamento.create!(nome: "DCC #{SecureRandom.hex(2)}") }
  let(:admin) { create_admin_usuario(departamento: departamento) }
  let(:usuario) { create_usuario }
  let(:template) { create_template_with_questoes(titulo: "Avaliação Docente", adm: admin.perfil_adm) }
  let(:turma_a) { create_turma(nome_materia: "MDS", numero: 1, departamento: departamento) }
  let(:turma_b) { create_turma(nome_materia: "IHC", numero: 2, departamento: departamento) }

  def preparar_formulario(template_id: template.id, turma_ids: [ turma_a.id, turma_b.id ])
    post preparar_formularios_path,
         params: { template_id: template_id, turma_ids: turma_ids }
  end

  describe "POST /formularios/preparar" do
    it "grava sessão e redireciona para publicação quando dados válidos" do
      sign_in_as(admin)

      preparar_formulario

      expect(response).to redirect_to(publicar_formularios_path)
      follow_redirect!
      expect(response.body).to include("Avaliação Docente")
      expect(response.body).to include(turma_a.nome_exibicao)
    end

    it "retorna erro quando nenhuma turma é selecionada" do
      sign_in_as(admin)

      expect do
        preparar_formulario(turma_ids: [])
      end.not_to change(Formulario, :count)

      expect(response).to redirect_to(new_formulario_path)
      follow_redirect!
      expect(response.body).to include("É necessário selecionar pelo menos uma turma")
    end
  end

  describe "GET /formularios/publicar" do
    it "redireciona para new quando sessão está vazia" do
      sign_in_as(admin)

      get publicar_formularios_path

      expect(response).to redirect_to(new_formulario_path)
    end
  end

  describe "POST /formularios" do
    it "cria formulários após wizard completo com público-alvo" do
      sign_in_as(admin)
      preparar_formulario

      expect do
        post formularios_path, params: { publico_alvo: "docentes" }
      end.to change(Formulario, :count).by(2)

      expect(response).to redirect_to(new_formulario_path)
      follow_redirect!
      expect(response.body).to include("Formulário criado com sucesso para as turmas selecionadas")
    end

    it "retorna erro quando público-alvo não é informado" do
      sign_in_as(admin)
      preparar_formulario(turma_ids: [ turma_a.id ])

      expect do
        post formularios_path, params: { publico_alvo: "" }
      end.not_to change(Formulario, :count)

      expect(response).to redirect_to(publicar_formularios_path)
      follow_redirect!
      expect(response.body).to include("Por favor, selecione o público-alvo do formulário")
    end

    it "redireciona para new quando sessão está vazia" do
      sign_in_as(admin)

      post formularios_path, params: { publico_alvo: "docentes" }

      expect(response).to redirect_to(new_formulario_path)
      follow_redirect!
      expect(response.body).to include("Selecione um template e as turmas antes de publicar")
    end

    it "bloqueia usuário não administrador" do
      sign_in_as(usuario)

      post formularios_path, params: { publico_alvo: "docentes" }

      expect(response).to redirect_to("/")
      follow_redirect!
      expect(response.body).to include("Acesso não autorizado")
      expect(Formulario.count).to eq(0)
    end
  end
end

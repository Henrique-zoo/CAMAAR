require "rails_helper"

RSpec.describe "Formularios", type: :request do
  let(:admin) { create_admin_usuario }
  let(:usuario) { create_usuario }
  let(:template) { create_template_with_questoes(titulo: "Avaliação Docente") }
  let(:turma_a) { create_turma(nome_materia: "MDS", codigo_turma: "A") }
  let(:turma_b) { create_turma(nome_materia: "IHC", codigo_turma: "B") }

  describe "POST /formularios" do
    it "cria formulários para múltiplas turmas quando admin autenticado" do
      sign_in_as(admin)

      expect do
        post formularios_path,
             params: {
               template_id: template.id,
               turma_ids: [turma_a.id, turma_b.id]
             }
      end.to change(Formulario, :count).by(2)

      expect(response).to redirect_to(new_formulario_path)
      follow_redirect!
      expect(response.body).to include("Formulário criado com sucesso para as turmas selecionadas")
    end

    it "retorna erro quando nenhuma turma é selecionada" do
      sign_in_as(admin)

      expect do
        post formularios_path,
             params: { template_id: template.id, turma_ids: [] }
      end.not_to change(Formulario, :count)

      expect(response).to redirect_to(new_formulario_path)
      follow_redirect!
      expect(response.body).to include("É necessário selecionar pelo menos uma turma")
    end

    it "bloqueia usuário não administrador" do
      sign_in_as(usuario)

      post formularios_path,
           params: {
             template_id: template.id,
             turma_ids: [turma_a.id]
           }

      expect(response).to redirect_to("/")
      follow_redirect!
      expect(response.body).to include("Acesso não autorizado")
      expect(Formulario.count).to eq(0)
    end
  end
end

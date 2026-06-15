require "rails_helper"

RSpec.describe "Templates", type: :request do
  let(:current_adm) { double("PerfilAdm", id: 1) }
  let(:current_usuario) do
    double(
      "Usuario",
      administrador?: true,
      perfil_adm: current_adm
    )
  end
  let(:template) do
    Template.new(
      id: 1,
      titulo: "Avaliação",
      descricao: "Descrição do template",
      adm_id: 1
    )
  end

  before do
    allow(template).to receive(:persisted?).and_return(true)
    allow_any_instance_of(ApplicationController)
      .to receive(:current_usuario)
      .and_return(current_usuario)

    allow_any_instance_of(ApplicationController)
      .to receive(:current_adm)
      .and_return(current_adm)

    allow_any_instance_of(ApplicationController)
      .to receive(:authorize!)
      .and_return(true)

    allow(template).to receive(:questoes).and_return([])
  end

  describe "GET /templates" do
    it "returns a successful response" do
      policy_scope = double("TemplatePolicyScope")
      included_scope = double("IncludedTemplates")
      ordered_scope = double("OrderedTemplates")

      allow_any_instance_of(ApplicationController)
        .to receive(:policy_scope)
        .with(Template)
        .and_return(policy_scope)

      allow(policy_scope)
        .to receive(:includes)
        .with(adm: :usuario)
        .and_return(included_scope)
      allow(included_scope).to receive(:recentes).and_return(ordered_scope)
      allow(ordered_scope)
        .to receive(:criados_por)
        .with(current_adm)
        .and_return([])
      allow(ordered_scope)
        .to receive(:criados_por_outros)
        .with(current_adm)
        .and_return([])

      get templates_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /templates/new" do
    it "returns a successful response" do
      new_template = Template.new(adm_id: 1)

      allow(new_template).to receive(:questoes).and_return([])
      allow(Template)
        .to receive(:new)
        .with(adm: current_adm)
        .and_return(new_template)

      get new_template_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /templates/:id" do
    it "returns a successful response" do
      allow(Template).to receive(:find).with("1").and_return(template)

      get template_path(template)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /templates" do
    it "creates a template and redirects to the created record" do
      new_template = Template.new(
        id: 1,
        titulo: "Avaliação",
        descricao: "Descrição",
        adm_id: 1
      )

      allow(new_template).to receive(:persisted?).and_return(true)
      allow(new_template).to receive(:adm=)
      allow(new_template).to receive(:save).and_return(true)
      allow(Template)
        .to receive(:new)
        .and_return(new_template)

      post templates_path, params: {
        template: {
          titulo: "Avaliação",
          descricao: "Descrição"
        }
      }

      expect(new_template).to have_received(:save)
      expect(response).to redirect_to(template_path(new_template))
    end
  end

  describe "GET /templates/:id/edit" do
    it "returns a successful response for the owner" do
      allow(Template).to receive(:find).with("1").and_return(template)

      get edit_template_path(template)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /templates/:id" do
    it "updates the template and redirects to the index" do
      allow(Template).to receive(:find).with("1").and_return(template)
      allow(template).to receive(:update).and_return(true)

      patch template_path(template), params: {
        template: { titulo: "Novo título" }
      }

      expect(template).to have_received(:update)
        .with(ActionController::Parameters.new(titulo: "Novo título").permit!)
      expect(response).to redirect_to(template_path(template))
    end
  end

  describe "DELETE /templates/:id" do
    it "destroys the template and redirects to the index" do
      allow(Template).to receive(:find).with("1").and_return(template)
      allow(template).to receive(:destroy)

      delete template_path(template)

      expect(template).to have_received(:destroy)
      expect(response).to redirect_to(templates_path)
    end
  end
end

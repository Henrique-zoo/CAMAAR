require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  # ADICIONADO O CAMPO EMAIL NOS MOCKS ABAIXO
  let(:usuario_comum) { double("UsuarioComum", id: 2, admin?: false, nome: "Rafael", matricula: "123456", email: "rafael@email.com") }
  let(:usuario_admin) { double("UsuarioAdmin", id: 3, admin?: true, nome: "Admin", matricula: "654321", email: "admin@email.com") }

  describe "GET /dashboard (index)" do
    it "redireciona para root se o usuário não estiver logado" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      
      get avaliacoes_path
      
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("Acesso restrito. Por favor, faça login para continuar.")
    end

    it "permite acesso e carrega as turmas se o usuário estiver logado" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(usuario_comum)
      
      get avaliacoes_path
      
      expect(response).to have_http_status(:success)
    end
  end

  describe "Acesso ao Gerenciamento (Filtro verificar_admin)" do
    it "bloqueia e desloga usuário comum que tentar acessar o gerenciamento" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(usuario_comum)
      
      get gerenciamento_path
      
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("Acesso restrito. Por favor, faça login como administrador.")
    end

    it "permite que o administrador acesse a página de gerenciamento" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(usuario_admin)
      
      get gerenciamento_path
      
      expect(response).to have_http_status(:success)
    end
  end

  describe "Barra Lateral (Sidebar View)" do
    it "NÃO exibe o link de Gerenciamento para usuários comuns" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(usuario_comum)
      
      get avaliacoes_path
      
      expect(response.body).not_to include('Gerenciamento')
    end

    it "EXIBE o link de Gerenciamento para usuários administradores" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(usuario_admin)
      
      get avaliacoes_path
      
      expect(response.body).to include('Gerenciamento')
      expect(response.body).to include(gerenciamento_path)
    end
  end
end
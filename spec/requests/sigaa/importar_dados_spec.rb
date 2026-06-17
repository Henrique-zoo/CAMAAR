require "rails_helper"

RSpec.describe "Importação de Dados SIGAA", type: :request do
  let(:usuario_admin) { double("UsuarioAdmin", id: 99, admin?: true, nome: "Admin", matricula: "654321", email: "admin@unb.br") }
  let(:caminho_arquivo) { Rails.root.join("db", "usuarios_sigaa.json") }

  before do
    Departamento.find_or_create_by!(id: 1)
    Departamento.find_or_create_by!(id: 2)

    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(usuario_admin)
  end
  describe "POST /importar_dados - Arquivo inexistente" do
    it "redireciona para o gerenciamento avisando que o arquivo sumiu" do
      allow(File).to receive(:exist?).with(caminho_arquivo).and_return(false)

      post importar_dados_path

      expect(response).to redirect_to(gerenciamento_path)
      expect(flash[:error]).to eq("Arquivo JSON não encontrado em db/")
    end
  end
  describe "POST /importar_dados - Sucesso Total" do
    let(:json_valido) do
      {
        "materias" => [
          { "codigo" => "CIC0001", "nome" => "Estruturas de Dados", "departamento_id_temp" => 1 }
        ],
        "turmas" => [
          { "numero" => 1, "ano" => 2026, "semestre" => 1, "materia_codigo" => "CIC0001" }
        ],
        "usuarios_docentes" => [
          { "matricula" => "2026001", "nome" => "Prof Teste", "email" => "prof@unb.br", "departamento_id_temp" => 1 }
        ],
        "usuarios_discentes" => [
          {
            "matricula" => "26100001",
            "nome" => "Rafael Sapienza",
            "email" => "rafael@unb.br",
            "turmas_matriculadas" => [
              { "materia_codigo" => "CIC0001", "numero_turma" => 1 }
            ]
          }
        ]
      }.to_json
    end

    it "sincroniza todos os dados perfeitamente no banco de dados" do
      allow(File).to receive(:exist?).with(caminho_arquivo).and_return(true)
      allow(File).to receive(:read).with(caminho_arquivo).and_return(json_valido)

      expect {
        post importar_dados_path
      }.to change(Materia, :count).by(1)
       .and change(Turma, :count).by(1)
       .and change(Usuario, :count).by(2)

      expect(response).to redirect_to(gerenciamento_path)
      expect(flash[:success]).to eq("Dados do SIGAA importados e sincronizados com sucesso!")
    end
  end
  describe "POST /importar_dados - Dados Corrompidos ou Inválidos" do
    let(:json_com_erro) do
      {
        "materias" => [
          { "codigo" => "CIC0001", "nome" => "Estruturas de Dados", "departamento_id_temp" => 1 }
        ],
        "turmas" => [], # Nenhuma turma mapeada para forçar o erro do aluno abaixo
        "usuarios_docentes" => [],
        "usuarios_discentes" => [
          {
            "matricula" => "26100001",
            "nome" => "Rafael Sapienza",
            "email" => "rafael@unb.br",
            "turmas_matriculadas" => [
              { "materia_codigo" => "CIC0001", "numero_turma" => 999 }
            ]
          }
        ]
      }.to_json
    end

    it "salva a matéria, mas falha ao matricular o aluno e gera relatório de erros" do
      allow(File).to receive(:exist?).with(caminho_arquivo).and_return(true)
      allow(File).to receive(:read).with(caminho_arquivo).and_return(json_com_erro)

      post importar_dados_path

      expect(response).to redirect_to(gerenciamento_path)
      expect(flash[:error]).to eq("A importação foi concluída parcialmente.")

      expect(flash[:error_list]).to include(
        "Discente Rafael Sapienza (Matrícula: 26100001): Turma nº 999 da matéria 'Estruturas de Dados' não foi localizada no sistema."
      )
    end
  end
end

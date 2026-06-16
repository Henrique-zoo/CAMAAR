require "rails_helper"

RSpec.describe Formulario, type: :model do
  let(:departamento) { Departamento.create!(nome: "DCC #{SecureRandom.hex(2)}") }
  let(:admin) { create_admin_usuario(departamento: departamento) }
  let(:turma) { create_turma(nome_materia: "MDS", numero: 1, departamento: departamento) }
  let(:template) { create_template_with_questoes(titulo: "Avaliação", adm: admin.perfil_adm) }

  describe "validações" do
    it "exige perfil administrativo" do
      formulario = described_class.new

      expect(formulario).not_to be_valid
      expect(formulario.errors[:adm]).to include("must exist")
    end
  end

  describe "#participacoes_alvo" do
    let!(:docente) do
      usuario = create_usuario
      create_participacao(usuario: usuario, turma: turma, tipo_participacao: :docente)
      usuario.participacoes_turma.sole
    end

    let!(:discente) do
      usuario = create_usuario
      create_participacao(usuario: usuario, turma: turma, tipo_participacao: :discente)
      usuario.participacoes_turma.sole
    end

    it "retorna participações docentes quando público-alvo é docentes" do
      formulario = create_formulario(turma: turma, adm: admin.perfil_adm, template: template, publico_alvo: :docentes)

      expect(formulario.participacoes_alvo).to contain_exactly(docente)
    end

    it "retorna participações discentes quando público-alvo é discentes" do
      formulario = create_formulario(turma: turma, adm: admin.perfil_adm, template: template, publico_alvo: :discentes)

      expect(formulario.participacoes_alvo).to contain_exactly(discente)
    end
  end

  describe "#criar_avaliacoes_pendentes!" do
    let!(:docente) do
      usuario = create_usuario
      create_participacao(usuario: usuario, turma: turma, tipo_participacao: :docente)
      usuario
    end

    let!(:discente) do
      usuario = create_usuario
      create_participacao(usuario: usuario, turma: turma, tipo_participacao: :discente)
      usuario
    end

    it "cria avaliações pendentes para cada participação do público-alvo" do
      formulario = create_formulario(turma: turma, adm: admin.perfil_adm, template: template, publico_alvo: :docentes)

      expect do
        formulario.criar_avaliacoes_pendentes!
      end.to change(Avaliacao, :count).by(1)

      avaliacao = formulario.avaliacoes.sole
      expect(avaliacao).to be_pendente
      expect(avaliacao.participacao_turma.usuario).to eq(docente)
    end

    it "não duplica avaliações existentes" do
      formulario = create_formulario(
        turma: turma,
        adm: admin.perfil_adm,
        template: template,
        publico_alvo: :discentes,
        criar_avaliacoes: true
      )

      expect do
        formulario.criar_avaliacoes_pendentes!
      end.not_to change(Avaliacao, :count)
    end
  end
end

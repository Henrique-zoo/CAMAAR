require "rails_helper"

RSpec.describe Formularios::CreateFromTemplate do
  let(:departamento) { Departamento.create!(nome: "DCC #{SecureRandom.hex(2)}") }
  let(:admin) { create_admin_usuario(departamento: departamento) }
  let(:perfil_adm) { admin.perfil_adm }
  let(:template) { create_template_with_questoes(titulo: "Avaliação Docente", adm: perfil_adm) }
  let(:turma_a) { create_turma(nome_materia: "MDS", numero: 1, departamento: departamento) }
  let(:turma_b) { create_turma(nome_materia: "IHC", numero: 2, departamento: departamento) }

  describe ".call" do
    it "cria um formulário por turma selecionada" do
      formularios = described_class.call(
        template_id: template.id,
        turma_ids: [turma_a.id, turma_b.id],
        perfil_adm: perfil_adm
      )

      expect(formularios.size).to eq(2)
      expect(Formulario.count).to eq(2)
      expect(turma_a.reload.formularios.sole).to eq(formularios.first)
      expect(turma_b.reload.formularios.sole).to eq(formularios.second)
    end

    it "copia as questões do template como snapshot independente" do
      formularios = described_class.call(
        template_id: template.id,
        turma_ids: [turma_a.id],
        perfil_adm: perfil_adm
      )

      formulario = formularios.first
      questoes_template = questoes_ordenadas_do_template(template)
      questoes_formulario = formulario.questoes.order(:id)

      expect(questoes_formulario.count).to eq(questoes_template.count)
      expect(questoes_formulario.pluck(:enunciado)).to eq(questoes_template.map(&:enunciado))
      expect(questoes_formulario.pluck(:tipo)).to eq(questoes_template.map(&:tipo))

      questao_template = questoes_template.first
      questao_formulario = questoes_formulario.first
      enunciado_original = questao_formulario.enunciado

      questao_template.update!(enunciado: "Enunciado alterado no template")

      expect(questao_formulario.reload.enunciado).to eq(enunciado_original)
    end

    it "copia opções para questões objetivas" do
      formularios = described_class.call(
        template_id: template.id,
        turma_ids: [turma_a.id],
        perfil_adm: perfil_adm
      )

      questao_objetiva = formularios.first.questoes.find_by(tipo: :objetiva)
      expect(questao_objetiva.opcoes.order(:numero).pluck(:texto)).to eq(%w[Ruim Regular Boa Excelente])
    end

    it "faz rollback se a criação de um formulário falhar" do
      call_count = 0

      allow(Formulario).to receive(:create!).and_wrap_original do |method, **args|
        call_count += 1
        raise ActiveRecord::RecordInvalid.new(Formulario.new) if call_count == 2

        method.call(**args)
      end

      expect do
        described_class.call(
          template_id: template.id,
          turma_ids: [turma_a.id, turma_b.id],
          perfil_adm: perfil_adm
        )
      end.to raise_error(ActiveRecord::RecordInvalid)

      expect(Formulario.count).to eq(0)
      expect(turma_a.reload.formularios).to be_empty
      expect(turma_b.reload.formularios).to be_empty
    end

    it "levanta erro quando nenhuma turma é selecionada" do
      expect do
        described_class.call(
          template_id: template.id,
          turma_ids: [],
          perfil_adm: perfil_adm
        )
      end.to raise_error(Formularios::Error, "É necessário selecionar pelo menos uma turma")

      expect(Formulario.count).to eq(0)
    end

    it "levanta erro quando turma já possui formulário" do
      described_class.call(
        template_id: template.id,
        turma_ids: [turma_a.id],
        perfil_adm: perfil_adm
      )

      expect do
        described_class.call(
          template_id: template.id,
          turma_ids: [turma_a.id],
          perfil_adm: perfil_adm
        )
      end.to raise_error(Formularios::Error, "Uma ou mais turmas selecionadas já possuem formulário")
    end
  end
end

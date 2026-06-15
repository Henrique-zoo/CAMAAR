require "rails_helper"

RSpec.describe Formularios::CreateFromTemplate do
  let(:admin) { create_admin_usuario }
  let(:perfil_adm) { admin.perfil_adm }
  let(:template) { create_template_with_questoes(titulo: "Avaliação Docente") }
  let(:turma_a) { create_turma(nome_materia: "MDS", codigo_turma: "A") }
  let(:turma_b) { create_turma(nome_materia: "IHC", codigo_turma: "B") }

  describe ".call" do
    it "cria um formulário por turma selecionada" do
      formularios = described_class.call(
        template_id: template.id,
        turma_ids: [turma_a.id, turma_b.id],
        perfil_adm: perfil_adm
      )

      expect(formularios.size).to eq(2)
      expect(Formulario.count).to eq(2)
      expect(turma_a.reload.formulario).to eq(formularios.first)
      expect(turma_b.reload.formulario).to eq(formularios.second)
    end

    it "copia as questões do template como snapshot independente" do
      formularios = described_class.call(
        template_id: template.id,
        turma_ids: [turma_a.id],
        perfil_adm: perfil_adm
      )

      formulario = formularios.first
      questoes_template = template.questoes.order(:posicao)
      questoes_formulario = formulario.questoes.order(:posicao)

      expect(questoes_formulario.count).to eq(questoes_template.count)
      expect(questoes_formulario.pluck(:enunciado)).to eq(questoes_template.pluck(:enunciado))
      expect(questoes_formulario.pluck(:tipo)).to eq(questoes_template.pluck(:tipo))

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
      expect(questao_objetiva.opcoes.pluck(:texto)).to eq(%w[Ruim Regular Boa Excelente])
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
      expect(turma_a.reload.formulario_id).to be_nil
      expect(turma_b.reload.formulario_id).to be_nil
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

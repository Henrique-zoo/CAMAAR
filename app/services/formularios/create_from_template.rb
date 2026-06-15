module Formularios
  class CreateFromTemplate
    SEM_TURMAS = "É necessário selecionar pelo menos uma turma"
    SEM_QUESTOES = "O template deve possuir pelo menos uma questão"
    TURMAS_INVALIDAS = "Uma ou mais turmas selecionadas são inválidas"
    TURMA_COM_FORMULARIO = "Uma ou mais turmas selecionadas já possuem formulário"

    def self.call(template_id:, turma_ids:, perfil_adm:)
      new(template_id:, turma_ids:, perfil_adm:).call
    end

    def initialize(template_id:, turma_ids:, perfil_adm:)
      @template_id = template_id
      @turma_ids = Array(turma_ids).map(&:to_i).uniq.reject(&:zero?)
      @perfil_adm = perfil_adm
    end

    def call
      validate_turma_ids!
      validate_template!
      validate_turmas!
      validate_turmas_sem_formulario!

      formularios = []

      ActiveRecord::Base.transaction do
        turmas.each do |turma|
          formulario = Formulario.create!(
            template: template,
            perfil_adm: perfil_adm
          )

          copy_questoes!(formulario)
          turma.update!(formulario: formulario)
          formularios << formulario
        end
      end

      formularios
    end

    private

    attr_reader :template_id, :turma_ids, :perfil_adm

    def validate_turma_ids!
      raise Error, SEM_TURMAS if turma_ids.empty?
    end

    def validate_template!
      raise Error, SEM_QUESTOES if template.questoes.none?
    end

    def validate_turmas!
      raise Error, TURMAS_INVALIDAS if turmas.count != turma_ids.size
    end

    def validate_turmas_sem_formulario!
      raise Error, TURMA_COM_FORMULARIO if turmas.where.not(formulario_id: nil).exists?
    end

    def template
      @template ||= Template.find(template_id)
    end

    def turmas
      @turmas ||= Turma.do_semestre_atual.where(id: turma_ids)
    end

    def copy_questoes!(formulario)
      template.questoes.order(:posicao).each do |questao_template|
        questao = formulario.questoes.create!(
          enunciado: questao_template.enunciado,
          tipo: questao_template.tipo,
          obrigatoria: questao_template.obrigatoria,
          posicao: questao_template.posicao
        )

        copy_opcoes!(questao_template, questao)
      end
    end

    def copy_opcoes!(questao_template, questao)
      return unless questao_template.objetiva?

      opcoes_template(questao_template).each do |texto|
        questao.opcoes.create!(texto: texto)
      end
    end

    def opcoes_template(questao_template)
      if questao_template.opcoes.any?
        questao_template.opcoes.pluck(:texto)
      elsif questao_template.read_attribute(:opcoes).present?
        Array(questao_template.read_attribute(:opcoes))
      else
        []
      end
    end
  end
end

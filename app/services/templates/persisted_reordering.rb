# frozen_string_literal: true

module Templates
  class PersistedReordering
    BOOLEAN = ActiveModel::Type::Boolean.new

    private_constant :BOOLEAN

    def self.prepare(template:, attributes:)
      new(template:, attributes:).prepare
    end

    def initialize(template:, attributes:)
      @template = template
      @utilizacoes_attributes = nested_values(attributes)
    end

    def prepare
      prepare_utilizacoes
      prepare_opcoes
    end

    private

    attr_reader :template, :utilizacoes_attributes

    def prepare_utilizacoes
      UtilizacaoQuestao
        .where(template_id: template.id, id: ids_for(utilizacoes_attributes))
        .find_each { |utilizacao| renumber(utilizacao) }
    end

    def prepare_opcoes
      Opcao
        .where(id: option_ids)
        .find_each { |opcao| renumber(opcao) }
    end

    def option_ids
      utilizacoes_attributes.flat_map do |attributes|
        ids_for(option_attributes_from(attributes))
      end
    end

    def option_attributes_from(attributes)
      question_attributes = nested_attribute(attributes, :questao_attributes)

      nested_values(nested_attribute(question_attributes, :opcoes_attributes))
    end

    def ids_for(attributes)
      attributes
        .reject { |item| destroy_attribute?(item) }
        .filter_map { |item| persisted_id_with_number(item) }
    end

    def destroy_attribute?(attributes)
      BOOLEAN.cast(nested_attribute(attributes, :_destroy))
    end

    def persisted_id_with_number(attributes)
      id = nested_attribute(attributes, :id)
      number = nested_attribute(attributes, :numero)

      id if id.present? && number.present?
    end

    def renumber(record)
      record.update_columns(numero: -record.id)
    end

    def nested_attribute(attributes, key)
      return if attributes.blank?

      attributes[key] || attributes[key.to_s]
    end

    def nested_values(attributes)
      return [] if attributes.blank?
      return attributes.values if attributes.is_a?(Hash)
      return attributes.values if attributes.is_a?(ActionController::Parameters)

      Array(attributes)
    end
  end
end

# frozen_string_literal: true

class TemplatesController < ApplicationController
  before_action :authenticate_usuario!

  def new
    @template = Template.new(adm: current_adm)
    preparar_campos_do_formulario

    authorize! @template
  end

  def create
    @template = Template.new(template_params)
    @template.adm = current_adm

    authorize! @template

    if @template.save
      redirect_to @template, notice: "Template criado com sucesso."
    else
      preparar_campos_do_formulario

      render :new, status: :unprocessable_entity
    end
  end

  private

  def preparar_campos_do_formulario
    utilizacoes = @template.utilizacao_questoes
    utilizacoes.build(numero: 1) if utilizacoes.empty?

    utilizacoes.each do |utilizacao|
      utilizacao.build_questao(tipo: :discursiva) if utilizacao.questao.blank?

      4.times { utilizacao.questao.opcoes.build }
    end
  end

  def template_params
    params
      .require(:template)
      .permit(
        :titulo,
        :descricao,
        utilizacoes_questao_attributes: [
          :id,
          :questao_id,
          :numero,
          :parent_id,
          :_destroy,
          questao_attributes: [
            :id,
            :enunciado,
            :tipo,
            opcoes_attributes: [
              :id,
              :texto,
              :numero,
              :_destroy
            ]
          ]
        ]
      )
  end
end

# frozen_string_literal: true

class TemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: %i[show edit update destroy]

  def index
    authorize! Template

    templates = policy_scope(Template)
      .includes(adm: :usuario)
      .recentes

    @user_templates = templates.criados_por(current_administrador)
    @other_templates = templates.criados_por_outros(current_administrador)
  end

  def show
    authorize! @template
  end

  def new
    @template = Template.new(adm: current_administrador)
    preparar_campos_do_template

    authorize! @template
  end

  def create
    @template = build_template

    authorize! @template

    if @template.save
      redirect_to @template, notice: "Template criado com sucesso."
    else
      preparar_campos_do_template

      render :new, status: :unprocessable_entity
    end
  end

  def edit
    preparar_campos_do_template

    authorize! @template
  end

  def update
    authorize! @template

    template_atualizado = atualizar_template_com_reordenacao

    if template_atualizado
      redirect_to @template, notice: "Template atualizado com sucesso."
    else
      preparar_campos_do_template

      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! @template

    @template.destroy

    redirect_to templates_path, notice: "Template excluído com sucesso."
  end

  private

  def set_template
    @template = Template.find(params[:id])
  end

  def build_template
    Template.new(template_params).tap do |template|
      template.adm = current_administrador
    end
  end

  def preparar_campos_do_template
    utilizacoes = @template.utilizacoes_questoes
    utilizacoes.build(numero: 1) if utilizacoes.empty?

    utilizacoes.each do |utilizacao|
      utilizacao.build_questao(tipo: nil) if utilizacao.questao.blank?
    end
  end

  def atualizar_template_com_reordenacao
    Template.transaction do
      preparar_reordenacao_de_registros_persistidos
      update_template_or_rollback
    end
  end

  def preparar_reordenacao_de_registros_persistidos
    Templates::PersistedReordering.prepare(
      template: @template,
      attributes: params.dig(:template, :utilizacoes_questoes_attributes)
    )
  end

  def update_template_or_rollback
    @template.update(template_params) || raise(ActiveRecord::Rollback)
  end

  def template_params
    params
      .require(:template)
      .permit(
        :titulo,
        :descricao,
        utilizacoes_questoes_attributes: [
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

# frozen_string_literal: true

class TemplatesController < ApplicationController
  before_action :authenticate_usuario!
  before_action :set_template, only: %i[show]

  def index
    authorize! Template

    templates = policy_scope(Template)
      .includes(adm: :usuario)
      .recentes

    @user_templates = templates.criados_por(current_adm)
    @other_templates = templates.criados_por_outros(current_adm)
  end

  def show
    authorize! @template
  end

  private

  def set_template
    @template = Template.find(params[:id])
  end
end

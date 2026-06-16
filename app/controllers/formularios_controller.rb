class FormulariosController < ApplicationController
  before_action :require_admin!

  def new
    @templates = Template.all
    @turmas = Turma.do_semestre_atual.sem_formulario.includes(:materia)
  end

  def preparar
    Formularios::CreateFromTemplate.validate_preparacao!(
      template_id: params[:template_id],
      turma_ids: params[:turma_ids]
    )

    session[:formulario_preparacao] = {
      "template_id" => params[:template_id].to_i,
      "turma_ids" => Array(params[:turma_ids]).map(&:to_i)
    }

    redirect_to publicar_formularios_path
  rescue Formularios::Error => e
    redirect_to new_formulario_path, alert: e.message
  end

  def publicar
    preparacao = session[:formulario_preparacao]
    unless preparacao
      redirect_to new_formulario_path
      return
    end

    @template = Template.find(preparacao["template_id"])
    @turmas = Turma.where(id: preparacao["turma_ids"]).includes(:materia)
  end

  def create
    preparacao = session[:formulario_preparacao]
    unless preparacao
      redirect_to new_formulario_path, alert: "Selecione um template e as turmas antes de publicar"
      return
    end

    Formularios::CreateFromTemplate.call(
      template_id: preparacao["template_id"],
      turma_ids: preparacao["turma_ids"],
      publico_alvo: params[:publico_alvo],
      perfil_adm: current_usuario.perfil_adm
    )

    session.delete(:formulario_preparacao)

    redirect_to new_formulario_path,
                notice: "Formulário criado com sucesso para as turmas selecionadas"
  rescue Formularios::Error => e
    if e.message == Formularios::CreateFromTemplate::SEM_PUBLICO_ALVO
      redirect_to publicar_formularios_path, alert: e.message
    else
      session.delete(:formulario_preparacao)
      redirect_to new_formulario_path, alert: e.message
    end
  end
end

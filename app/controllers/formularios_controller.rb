class FormulariosController < ApplicationController
  before_action :require_admin!

  def new
    @templates = Template.all
    @turmas = Turma.do_semestre_atual.sem_formulario.includes(:materia)
  end

  def create
    Formularios::CreateFromTemplate.call(
      template_id: params[:template_id],
      turma_ids: params[:turma_ids],
      perfil_adm: current_usuario.perfil_adm
    )

    redirect_to new_formulario_path,
                notice: "Formulário criado com sucesso para as turmas selecionadas"
  rescue Formularios::Error => e
    redirect_to new_formulario_path, alert: e.message
  end
end

require 'csv'

class FormulariosController < ApplicationController
  before_action :require_login

  def exportar_csv
    @formulario = Formulario.find(params[:id])
    
    unless current_usuario&.perfil_adm
      redirect_to pendentes_avaliacoes_path, alert: 'Apenas administradores possuem acesso a este recurso'
      return
    end

    avaliacoes = @formulario.avaliacoes
                            .joins(:respostas)
                            .distinct
                            .includes(participacao_turma: { usuario: :perfil_discente }, 
                                      respostas: [ :questao, :texto, { opcoes_escolhidas: :opcao } ])

    questoes = @formulario.template.questoes.order('utilizacoes_questoes.numero')

    csv_data = CSV.generate(headers: true, col_sep: ';') do |csv|
      cabecalho = ['Aluno', 'Matrícula'] + questoes.map(&:enunciado)
      csv << cabecalho

      avaliacoes.each do |avaliacao|
        usuario = avaliacao.participacao_turma.usuario
        matricula = usuario.perfil_discente&.matricula || 'N/A'
        
        linha = [usuario.nome, matricula]
        
        questoes.each do |questao|
          resposta = avaliacao.respostas.find { |r| r.questao_id == questao.id }
          
          if resposta.nil?
            linha << 'Sem resposta'
          elsif questao.discursiva?
            linha << resposta.texto&.texto.to_s.strip # Busca o texto dentro do objeto Texto
          else
            linha << resposta.opcoes_escolhidas.map { |oe| oe.opcao.texto }.join(', ')
          end
        end
        
        csv << linha
      end
    end

    send_data csv_data, 
              filename: "resultados_turma_#{@formulario.turma.materia.codigo}_#{Date.today}.csv", 
              type: 'text/csv; charset=utf-8'
  end

  private

  def require_login
    redirect_to "/", alert: 'Usuário não autenticado' unless current_usuario
  end
end
class FormulariosController < ApplicationController
  before_action :require_admin!

  def index
    @formularios = Formulario
      .do_departamento(current_usuario.perfil_adm.departamento)
      .do_semestre_atual
      .recentes
      .includes(:template, turma: :materia)
  end

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

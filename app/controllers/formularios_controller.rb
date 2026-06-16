require 'csv'

class FormulariosController < ApplicationController
  before_action :require_login
  # ... (seus outros métodos como index, show)

  def exportar_csv
    @formulario = Formulario.find(params[:id])
    
    # Bloqueio de segurança: Apenas o admin responsável pode baixar
    unless current_usuario.perfil_adm && current_usuario.perfil_adm.departamento_id == @formulario.turma.materia.departamento_id
      return redirect_to root_path, alert: 'Acesso negado.'
    end

    avaliacoes = @formulario.avaliacoes.where(status: 'respondida')
                            .includes(participacao_turma: { usuario: :perfil_discente }, respostas: { questao: :opcoes })

    csv_data = CSV.generate(headers: true, col_sep: ';') do |csv|
      csv << ['Aluno', 'Matricula', 'Questao', 'Resposta']

      avaliacoes.each do |avaliacao|
        usuario = avaliacao.participacao_turma.usuario
        matricula = usuario.perfil_discente&.matricula || 'N/A'

        avaliacao.respostas.each do |resposta|
          texto_resposta = resposta.questao.discursiva? ? resposta.texto : resposta.opcoes_escolhidas.map { |oe| oe.opcao.texto }.join(', ')
          csv << [usuario.nome, matricula, resposta.questao.enunciado, texto_resposta]
        end
      end
    end

    send_data csv_data, 
              filename: "resultados_turma_#{@formulario.turma.materia.codigo}_#{Date.today}.csv", 
              type: 'text/csv; charset=utf-8'
  end
end
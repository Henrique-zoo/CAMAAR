require "json"


class DashboardController < ApplicationController
  before_action :verificar_admin, only: [ :gerenciamento, :importar_dados ]

  def index
    if current_user.nil?
      redirect_to root_path, flash: { error: "Acesso restrito. Por favor, faça login para continuar." } and return
    end
    @turmas_simuladas = [
      { materia: "Estruturas de Dados", semestre: "2026.1", professor: "Alessandro Silva" },
      { materia: "Bancos de Dados", semestre: "2026.1", professor: "Alessandro Silva" },
      { materia: "Cálculo 1", semestre: "2026.1", professor: "Maria Carmo" },
      { materia: "Compiladores", semestre: "2026.1", professor: "A definir" },
      { materia: "Sistemas Operacionais", semestre: "2026.1", professor: "A definir" }
    ]
  end

  def gerenciamento
  end

  def importar_dados
    caminho_arquivo = Rails.root.join("db", "usuarios_sigaa.json")
    unless File.exist?(caminho_arquivo)
      redirect_to gerenciamento_path, flash: { error: "Arquivo JSON não encontrado em db/" } and return
    end
    dados = JSON.parse(File.read(caminho_arquivo))
    codigos_materias_ativos = []
    turmas_ativas_ids = []
    matriculas_ativas_json = []
    erros_importacao = []
    dados["materias"]&.each do |materia_json|
      codigo = materia_json["codigo"]

      ActiveRecord::Base.transaction do
        codigos_materias_ativos << codigo

        materia = Materia.find_or_initialize_by(codigo: codigo)
        materia.nome = materia_json["nome"]
        materia.departamento_id = materia_json["departamento_id_temp"]
        materia.save!
      end
    rescue => e
      erros_importacao << "Matéria #{materia_json['nome']} (Código: #{codigo}): #{e.message}"
    end
    ActiveRecord::Base.transaction do
      dados["turmas"]&.each do |turma_json|
        materia = Materia.find_by(codigo: turma_json["materia_codigo"])
        next unless materia

        turma = Turma.find_or_initialize_by(
          numero: turma_json["numero"],
          ano: turma_json["ano"],
          semestre: turma_json["semestre"],
          materia_id: materia.id
        )
        turma.save!
        turmas_ativas_ids << turma.id
      end
    end
    dados["usuarios_docentes"]&.each do |docente_json|
      matricula = docente_json["matricula"]
      ActiveRecord::Base.transaction do
        matriculas_ativas_json << matricula
        usuario = Usuario.find_or_initialize_by(matricula: matricula)
        usuario.nome = docente_json["nome"]
        usuario.email = docente_json["email"]
        if usuario.new_record?
          usuario.status = 0
          usuario.senha = ""
        end
        usuario.save!
        perfil = PerfilDocente.find_or_initialize_by(id: usuario.id)
        perfil.departamento_id = docente_json["departamento_id_temp"]
        perfil.save!
      end
    rescue => e
      erros_importacao << "Docente #{docente_json['nome']} (Matrícula: #{matricula}): #{e.message}"
    end
    dados["usuarios_discentes"]&.each do |discente_json|
      matricula = discente_json["matricula"]
      ActiveRecord::Base.transaction do
        matriculas_ativas_json << matricula

        usuario = Usuario.find_or_initialize_by(matricula: matricula)
        usuario.nome = discente_json["nome"]
        usuario.email = discente_json["email"]
        if usuario.new_record?
          usuario.status = 0
          usuario.senha = ""
        end
        usuario.save!
        PerfilDiscente.find_or_create_by!(id: usuario.id)
        turmas_aluno_ids = []
        discente_json["turmas_matriculadas"].each do |mat_json|
          materia = Materia.find_by(codigo: mat_json["materia_codigo"])
          if materia.nil?
            raise "Matéria com código '#{mat_json['materia_codigo']}' não existe no sistema."
          end
          turma = Turma.find_by(materia_id: materia.id, numero: mat_json["numero_turma"], ano: 2026, semestre: 1)
          if turma.nil?
            raise "Turma nº #{mat_json['numero_turma']} da matéria '#{materia.nome}' não foi localizada no sistema."
          end

          turmas_aluno_ids << turma.id
          ParticipacaoTurma.find_or_create_by!(usuario_id: usuario.id, turma_id: turma.id)
        end
        usuario.participacoes_turma.where.not(turma_id: turmas_aluno_ids).destroy_all
      end
    rescue => e
      erros_importacao << "Discente #{discente_json['nome']} (Matrícula: #{matricula}): #{e.message}"
    end
    ActiveRecord::Base.transaction do
      Turma.where.not(id: turmas_ativas_ids).destroy_all
      Materia.where.not(codigo: codigos_materias_ativos).destroy_all
      usuarios_para_remover = Usuario.where.not(matricula: matriculas_ativas_json)
      usuarios_para_remover.each do |usuario|
        next if usuario.admin?
        usuario.destroy!
      end
    end
    if erros_importacao.empty?
      redirect_to gerenciamento_path, flash: { success: "Dados do SIGAA importados e sincronizados com sucesso!" }
    else
      redirect_to gerenciamento_path, flash: { error: "A importação foi concluída parcialmente.", error_list: erros_importacao }
    end
  end

  private

  def verificar_admin
    if current_user.nil? || !current_user.admin?
      session.clear
      @current_user = nil
      redirect_to root_path, flash: { error: "Acesso restrito. Por favor, faça login como administrador." }
    end
  end
end

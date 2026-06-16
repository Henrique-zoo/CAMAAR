require "json"


class DashboardController < ApplicationController
  before_action :verificar_admin, only: [ :gerenciamento ]

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

  private

  def verificar_admin
    if current_user.nil? || !current_user.admin?
      session.clear
      @current_user = nil
      redirect_to root_path, flash: { error: "Acesso restrito. Por favor, faça login como administrador." }
    end
  end
end

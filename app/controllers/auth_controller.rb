require "net/http"
require "uri"
require "json"

class AuthController < ApplicationController
  def index
    if current_user.present?
      redirect_to avaliacoes_path, flash: { notice: "Você já está conectado no sistema. Se quiser sair, faça log out" } and return
    end
  end

  def logout
    session.clear
    @current_user = nil
    redirect_to root_path, flash: { success: "Sessão encerrada com sucesso." }
  end

  def login
    identificador = params[:identificador].to_s.strip
    senha = params[:senha]
    email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
    if identificador.match?(email_regex)
      usuario = Usuario.find_by(email: identificador)
    else
      usuario = Usuario.find_by(matricula: identificador)
    end
    if usuario.nil?
      redirect_to root_path, flash: { error: "Matrícula ou e-mail inválido." } and return
    end
    if usuario.status != 1
      redirect_to root_path, flash: { error: "Esta conta ainda não foi ativada. Por favor, realize o Primeiro Acesso." } and return
    end
    if usuario.authenticate_senha(senha)
      session[:usuario_id] = usuario.id
      redirect_to avaliacoes_path, flash: { success: "Login realizado com sucesso! Seja bem-vindo." }
    else
      redirect_to root_path, flash: { error: "Senha incorreta." }
    end
  end
end

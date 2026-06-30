# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

# Controla autenticação, primeiro acesso e redefinição de senha.
#
# Este controller atende usuários importados do SIGAA que precisam ativar a
# conta por token, além do fluxo comum de login e recuperação de senha.
class AuthController < ApplicationController
  include BrevoEmailable

  before_action :impedir_se_logado,
    only: %i[solicitar_cadastro cadastrar solicitar_redef_senha redefinir_senha]
  before_action :validar_token_via_url, only: %i[cadastrar redefinir_senha]

  # Exibe a tela inicial de login.
  #
  # @return [void]
  # @side_effect Redireciona usuários já autenticados para a lista de avaliações.
  def index
    return unless current_user.present?

    redirect_to avaliacoes_path,
      flash: { notice: "Você já está conectado no sistema. Se quiser sair, faça log out" }
  end

  # Exibe o formulário de solicitação de primeiro acesso.
  #
  # @return [void]
  # @side_effect Renderiza a tela para informar matrícula e e-mail institucional.
  def solicitar_cadastro
  end

  # Exibe o formulário de definição de senha por token de cadastro.
  #
  # @return [void]
  # @side_effect Renderiza a tela de criação de senha após validação do token na
  #   URL.
  def cadastrar
  end

  # Exibe o formulário de solicitação de redefinição de senha.
  #
  # @return [void]
  # @side_effect Renderiza a tela para informar o e-mail cadastrado.
  def solicitar_redef_senha
  end

  # Exibe o formulário de escolha de nova senha por token de redefinição.
  #
  # @return [void]
  # @side_effect Renderiza a tela de redefinição após validação do token na URL.
  def redefinir_senha
  end

  # Encerra a sessão atual.
  #
  # @return [void]
  # @side_effect Limpa a sessão, remove o cache de usuário atual e redireciona
  #   para a página inicial.
  def logout
    session.clear
    @current_user = nil

    redirect_to root_path, flash: { success: "Sessão encerrada com sucesso." }
  end

  # Autentica o usuário por matrícula ou e-mail e senha.
  #
  # @return [void]
  # @side_effect Grava o ID do usuário na sessão quando a senha é válida ou
  #   redireciona para a tela inicial com mensagem de erro.
  def login
    usuario = buscar_usuario_por_identificador(params[:identificador])

    if usuario.nil?
      redirect_to root_path, flash: { error: "Matrícula ou e-mail inválido." }
      return
    end

    unless usuario.ativo?
      redirect_to root_path,
        flash: { error: "Esta conta ainda não foi ativada. Por favor, realize o Primeiro Acesso." }
      return
    end

    if usuario.authenticate_senha(params[:senha])
      session[:usuario_id] = usuario.id
      redirect_to avaliacoes_path, flash: { success: "Login realizado com sucesso! Seja bem-vindo." }
    else
      redirect_to root_path, flash: { error: "Senha incorreta." }
    end
  end

  # Processa a solicitação de primeiro acesso de usuário importado.
  #
  # Valida matrícula e e-mail contra os dados já importados do SIGAA, gera um
  # token de cadastro e envia o link de definição de senha.
  #
  # @return [void]
  # @side_effect Cria Token, envia e-mail de cadastro via Brevo e redireciona
  #   com flash de sucesso ou erro.
  def processar_solicitacao_cadastro
    unless email_valido?(params[:email])
      return redirecionar_com_erro(cadastro_path, "Por favor, insira um formato de e-mail válido.")
    end

    usuario = Usuario.find_by(matricula: params[:matricula])
    return redirecionar_com_erro(cadastro_path, "Matrícula não encontrada no sistema institucional.") if usuario.nil?

    if usuario.email.to_s.downcase.strip != params[:email].to_s.downcase.strip
      return redirecionar_com_erro(
        cadastro_path,
        "O e-mail informado não corresponde ao e-mail institucional desta matrícula."
      )
    end

    if usuario.ativo?
      return redirecionar_com_erro(
        cadastro_path,
        "Esta matrícula já possui um cadastro ativo. Caso tenha esquecido sua senha, utilize a redefinição."
      )
    end

    token_gerado = SecureRandom.hex(16)
    usuario.tokens.create!(
      value: token_gerado,
      tipo: "cadastro",
      expires_at: 10.minutes.from_now
    )

    if enviar_email_cadastro(usuario.email, token_gerado)
      redirect_to root_path, flash: { success: mensagem_email_enviado("10 minutos") }
    else
      redirect_to cadastro_path,
        flash: { error: "Houve um erro técnico ao tentar enviar o e-mail. Tente novamente mais tarde." }
    end
  end

  # Confirma o primeiro acesso e ativa a conta do usuário.
  #
  # Usa o token de cadastro para localizar o usuário, define a senha informada e
  # altera o status para ativo.
  #
  # @return [void]
  # @side_effect Atualiza Usuario, remove o Token usado e redireciona para login
  #   ou de volta ao formulário quando houver erro.
  def confirmar_cadastro
    if params[:senha].length < 6
      return redirecionar_com_erro(
        confirmar_cadastro_path(token: params[:token]),
        "A senha deve conter pelo menos 6 caracteres."
      )
    end

    if params[:senha] != params[:senha_confirmacao]
      return redirecionar_com_erro(
        confirmar_cadastro_path(token: params[:token]),
        "As senhas não coincidem. Digite novamente."
      )
    end

    token_registro = buscar_token_valido(params[:token], "cadastro")
    if token_registro.nil?
      return redirecionar_com_erro(
        root_path,
        "O link de confirmação é inválido, expirou ou não corresponde a esta operação."
      )
    end

    usuario = token_registro.usuario
    usuario.senha = params[:senha]
    usuario.senha_confirmation = params[:senha_confirmacao]
    usuario.status = :ativo

    if usuario.save
      token_registro.destroy
      redirect_to root_path, flash: { success: "Cadastro concluído com sucesso! Faça seu login." }
    else
      redirect_to confirmar_cadastro_path(token: params[:token]),
        flash: { error: usuario.errors.full_messages.to_sentence }
    end
  end

  # Processa uma solicitação de recuperação de senha.
  #
  # @return [void]
  # @side_effect Cria Token do tipo redefinição, envia e-mail de recuperação e
  #   redireciona com flash de sucesso ou erro.
  def processar_redefinicao_senha
    unless email_valido?(params[:email])
      return redirecionar_com_erro(solicitar_redef_senha_path, "Por favor, insira um formato de e-mail válido.")
    end

    usuario = Usuario.find_by(email: params[:email])
    return redirecionar_com_erro(solicitar_redef_senha_path, "Este e-mail não está cadastrado no sistema.") if usuario.nil?

    token_gerado = SecureRandom.hex(16)
    usuario.tokens.create!(
      value: token_gerado,
      tipo: "redefinicao",
      expires_at: 10.minutes.from_now
    )

    if enviar_email_redefinicao(params[:email], token_gerado)
      redirect_to root_path, flash: { success: mensagem_email_enviado("10 minutos") }
    else
      redirect_to solicitar_redef_senha_path,
        flash: { error: "Houve um erro técnico ao tentar enviar o e-mail de recuperação. Tente novamente mais tarde." }
    end
  end

  # Confirma a redefinição de senha por token válido.
  #
  # @return [void]
  # @side_effect Atualiza a senha do Usuario, remove o Token usado e redireciona
  #   para login ou de volta ao formulário quando houver erro.
  def confirmar_redefinicao_senha
    if params[:senha].length < 6
      return redirecionar_com_erro(
        redefinir_senha_path(token: params[:token]),
        "A nova senha deve conter pelo menos 6 caracteres."
      )
    end

    if params[:senha] != params[:senha_confirmacao]
      return redirecionar_com_erro(
        redefinir_senha_path(token: params[:token]),
        "As senhas não coincidem. Digite novamente."
      )
    end

    token_registro = buscar_token_valido(params[:token], "redefinicao")
    if token_registro.nil?
      return redirecionar_com_erro(
        root_path,
        "O link de redefinição é inválido, expirou ou não corresponde a esta operação."
      )
    end

    usuario = token_registro.usuario
    usuario.senha = params[:senha]
    usuario.senha_confirmation = params[:senha_confirmacao]

    if usuario.save
      token_registro.destroy
      redirect_to root_path,
        flash: { success: "Sua senha foi alterada com sucesso! Insira suas novas credenciais para acessar." }
    else
      redirect_to redefinir_senha_path(token: params[:token]),
        flash: { error: usuario.errors.full_messages.to_sentence }
    end
  end

  private

  # Impede que usuários autenticados acessem fluxos públicos de senha.
  #
  # @return [void]
  # @side_effect Redireciona usuários já logados para avaliações com flash de
  #   erro.
  def impedir_se_logado
    return unless current_user.present?

    redirect_to avaliacoes_path,
      flash: { error: "Você já está logado em outra sessão. Faça o logout antes de poder terminar essa ação." }
  end

  # Valida o token presente na URL para telas de cadastro ou redefinição.
  #
  # @return [void]
  # @side_effect Redireciona para a página inicial quando o token é inválido,
  #   expirado ou incompatível com a operação.
  def validar_token_via_url
    tipo_esperado = action_name == "cadastrar" ? "cadastro" : "redefinicao"
    token = buscar_token_valido(params[:token], tipo_esperado)

    redirect_to root_path, flash: { error: "Token inválido ou expirado." } if token.nil?
  end

  # Busca usuário por e-mail ou matrícula.
  #
  # @param identificador [String] E-mail ou matrícula informados no login.
  # @return [Usuario, nil] Usuário encontrado ou +nil+ quando não houver
  #   correspondência.
  def buscar_usuario_por_identificador(identificador)
    identificador = identificador.to_s.strip

    if email_valido?(identificador)
      Usuario.find_by(email: identificador)
    else
      Usuario.find_by(matricula: identificador)
    end
  end

  # Verifica se o e-mail possui formato básico válido.
  #
  # @param email [String, nil] Endereço a ser validado.
  # @return [Boolean] +true+ quando o e-mail está presente e segue o formato
  #   esperado; caso contrário, +false+.
  def email_valido?(email)
    email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
    email.present? && email.match?(email_regex)
  end

  # Localiza um token ainda válido para a operação esperada.
  #
  # @param valor [String] Valor bruto do token recebido pela URL ou formulário.
  # @param tipo_esperado [String] Tipo esperado, como "cadastro" ou
  #   "redefinicao".
  # @return [Token, nil] Token encontrado quando existe e não expirou; +nil+
  #   quando ausente, expirado ou de tipo incompatível.
  def buscar_token_valido(valor, tipo_esperado)
    token = Token.find_by(value: valor, tipo: tipo_esperado)
    return nil if token.nil? || token.expires_at < Time.current

    token
  end

  # Redireciona para uma rota exibindo mensagem de erro.
  #
  # @param caminho [String] Caminho Rails para onde o usuário será redirecionado.
  # @param mensagem [String] Mensagem exibida no flash de erro.
  # @return [void]
  # @side_effect Interrompe o fluxo atual com redirect e flash.
  def redirecionar_com_erro(caminho, mensagem)
    redirect_to caminho, flash: { error: mensagem }
  end

  # Monta o HTML exibido após envio de e-mail com token.
  #
  # @param validade [String] Texto com a validade do link enviado.
  # @return [String] Fragmento HTML com orientação ao usuário.
  def mensagem_email_enviado(validade)
    <<~HTML
      E-mail enviado com sucesso! Caso não o veja na caixa de entrada, cheque sua caixa de spam.
      <p style="color: #856404; background-color: #fff3cd; border: 1px solid #ffeeba; border-radius: 4px; padding: 8px; font-size: 12px; text-align: center; margin-top: 10px; margin-bottom: 0; font-family: sans-serif;">
        ⚠️ O link enviado terá validade de <strong>#{validade}</strong>.
      </p>
    HTML
  end
end

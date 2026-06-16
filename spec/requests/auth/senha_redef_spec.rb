# spec/requests/auth/senha_redef_spec.rb
require 'rails_helper'

RSpec.describe "Redefinição de Senha", type: :request do
  # Cria um usuário base com a matrícula fictícia para passar nas validações do seu modelo
  let!(:usuario) do
    Usuario.create!(
      email: "usuario@teste.com",
      senha: "SenhaAntiga123",
      senha_confirmation: "SenhaAntiga123",
      matricula: "202600123",
      status: 1
    )
  end

  describe "POST /redefinir-senha" do
    context "quando o formato do e-mail é inválido" do
      it "redireciona de volta com mensagem de erro" do
        post solicitar_redef_senha_path, params: { email: "email_invalido" }

        expect(response).to redirect_to(solicitar_redef_senha_path)
        expect(flash[:error]).to eq("Por favor, insira um formato de e-mail válido.")
      end
    end

    context "quando o e-mail não está cadastrado" do
      it "redireciona de volta informando que não existe" do
        post solicitar_redef_senha_path, params: { email: "nao_existe@teste.com" }

        expect(response).to redirect_to(solicitar_redef_senha_path)
        expect(flash[:error]).to eq("Este e-mail não está cadastrado no sistema.")
      end
    end

    context "quando o e-mail é válido e cadastrado" do
      context "e o envio do e-mail ocorre com sucesso" do
        before do
          # SIMULAÇÃO CORRETA: Intercepta o método no AuthController
          allow_any_instance_of(AuthController).to receive(:enviar_email_redefinicao).and_return(true)
        end

        it "gerencia o token no banco e redireciona para a home com sucesso" do
          expect {
            post solicitar_redef_senha_path, params: { email: "usuario@teste.com" }
          }.to change(usuario.tokens, :count).by(1)

          expect(response).to redirect_to(root_path)
          expect(flash[:success]).to include("10 minutos")

          # Garante que as propriedades do token foram salvas corretamente
          novo_token = usuario.tokens.last
          expect(novo_token.tipo).to eq("redefinicao")
          expect(novo_token.value).to be_present
          expect(novo_token.expires_at).to be > Time.current
        end
      end

      context "e ocorre um erro técnico no envio do e-mail" do
        before do
          # SIMULAÇÃO: Força o método a falhar (retornar false) para testar o else
          allow_any_instance_of(AuthController).to receive(:enviar_email_redefinicao).and_return(false)
        end

        it "não salva o fluxo com sucesso e exibe mensagem de erro técnico" do
          post solicitar_redef_senha_path, params: { email: "usuario@teste.com" }

          expect(response).to redirect_to(solicitar_redef_senha_path)
          expect(flash[:error]).to include("Houve um erro técnico ao tentar enviar o e-mail")
        end
      end
    end
  end

  describe "POST /redefinir-senha/confirmar" do
    # Cria um token válido no banco associado ao usuário para os contextos de sucesso
    let!(:token_valido) { usuario.tokens.create!(value: "token_secreto_123", tipo: "redefinicao", expires_at: 10.minutes.from_now) }

    context "quando a nova senha tem menos de 6 caracteres" do
      it "recusa a alteração" do
        # Ajustado para usar strings de rota diretas, evitando helpers desalinhados
        post "/redefinir-senha/confirmar", params: { token: "token_secreto_123", senha: "123", senha_confirmacao: "123" }

        expect(response).to redirect_to(redefinir_senha_path(token: "token_secreto_123"))
        expect(flash[:error]).to eq("A nova senha deve conter pelo menos 6 caracteres.")
      end
    end

    context "quando as senhas não coincidem" do
      it "recusa a alteração" do
        post "/redefinir-senha/confirmar", params: { token: "token_secreto_123", senha: "NovaSenha123", senha_confirmacao: "Diferente123" }

        expect(response).to redirect_to(redefinir_senha_path(token: "token_secreto_123"))
        expect(flash[:error]).to eq("As senhas não coincidem. Digite novamente.")
      end
    end

    context "quando o token é inválido ou expirou" do
      it "redireciona para a raiz com erro" do
        post "/redefinir-senha/confirmar", params: { token: "token_inexistente", senha: "NovaSenha123", senha_confirmacao: "NovaSenha123" }

        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("O link de redefinição é inválido, expirou ou não corresponde a esta operação.")
      end
    end

    context "quando todos os dados são válidos" do
      it "altera a senha do usuário, destrói o token e redireciona para a home" do
        post "/redefinir-senha/confirmar", params: { token: "token_secreto_123", senha: "NovaSenha123", senha_confirmacao: "NovaSenha123" }

        expect(response).to redirect_to(root_path)
        expect(flash[:success]).to eq("Sua senha foi alterada com sucesso! Insira suas novas credenciais para acessar.")

        # Garante que o token consumido foi devidamente deletado
        expect(Token.find_by(id: token_valido.id)).to be_nil
      end
    end

    context "quando o banco falha ao salvar o usuário por outra validação interna" do
      before do
        # Simula uma falha na hora do usuario.save
        allow_any_instance_of(Usuario).to receive(:save).and_return(false)
        # Permite que os erros do modelo retornem uma mensagem controlada
        allow_any_instance_of(ActiveModel::Errors).to receive(:full_messages).and_return([ "Erro customizado do modelo" ])
      end

      it "redireciona para a página de redefinição exibindo os erros do modelo" do
        post "/redefinir-senha/confirmar", params: { token: "token_secreto_123", senha: "NovaSenha123", senha_confirmacao: "NovaSenha123" }

        expect(response).to redirect_to(redefinir_senha_path(token: "token_secreto_123"))
        expect(flash[:error]).to eq("Erro customizado do modelo")
      end
    end
  end
end

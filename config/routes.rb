Rails.application.routes.draw do
  root "auth#index"
  get "/", to: "auth#index", as: :login
  get "/cadastro", to: "auth#solicitar_cadastro", as: :cadastro
  get "/cadastro/confirmar", to: "auth#cadastrar", as: :confirmar_cadastro
  get "/avaliacoes", to: "dashboard#index", as: :avaliacoes
  get "/gerenciamento", to: "dashboard#gerenciamento", as: :gerenciamento
  get "/redefinir-senha", to: "auth#solicitar_redef_senha", as: :solicitar_redef_senha
  get "/redefinir-senha/confirmar", to: "auth#redefinir_senha", as: :redefinir_senha
  post "/", to: "auth#login"
  post "/cadastro", to: "auth#processar_solicitacao_cadastro"
  post "cadastro/confirmar", to: "auth#confirmar_cadastro"
  post "/redefinir-senha", to: "auth#processar_redefinicao_senha"
  post "/redefinir-senha/confirmar", to: "auth#confirmar_redefinicao_senha"
  post "/gerenciamento/importar_dados", to: "dashboard#importar_dados", as: :importar_dados
  post "dashboard/enviar_solicitacoes", to: "dashboard#enviar_solicitacoes", as: :enviar_solicitacoes
  delete "/logout", to: "auth#logout", as: :logout
end

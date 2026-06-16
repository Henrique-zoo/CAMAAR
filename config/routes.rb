Rails.application.routes.draw do
  root "auth#index"
  get "/", to: "auth#index", as: :login
  get "/cadastro", to: "auth#solicitar_cadastro", as: :cadastro
  get "/cadastro/confirmar", to: "auth#cadastrar", as: :confirmar_cadastro
  get "/avaliacoes", to: "dashboard#index", as: :avaliacoes
  get "/gerenciamento", to: "dashboard#gerenciamento", as: :gerenciamento
  post "/", to: "auth#login"
  post "/cadastro", to: "auth#processar_solicitacao_cadastro"
  post "cadastro/confirmar", to: "auth#confirmar_cadastro"
  post "/gerenciamento/importar_dados", to: "dashboard#importar_dados", as: :importar_dados
  delete "/logout", to: "auth#logout", as: :logout
end

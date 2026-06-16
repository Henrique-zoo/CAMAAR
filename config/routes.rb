Rails.application.routes.draw do
  root "auth#index"
  get "/", to: "auth#index", as: :login
  get "/avaliacoes", to: "dashboard#index", as: :avaliacoes
  get "/gerenciamento", to: "dashboard#gerenciamento", as: :gerenciamento
  post "/", to: "auth#login"
  post "/gerenciamento/importar_dados", to: "dashboard#importar_dados", as: :importar_dados
  delete "/logout", to: "auth#logout", as: :logout
end

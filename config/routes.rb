Rails.application.routes.draw do
  root "auth#index"
  get "/", to: "auth#index", as: :login
  post "/", to: "auth#login"
  delete "/logout", to: "auth#logout", as: :logout
  get "/avaliacoes", to: "dashboard#index", as: :avaliacoes
  get "/gerenciamento", to: "dashboard#gerenciamento", as: :gerenciamento
end

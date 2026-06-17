# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :avaliacoes, only: [] do
    collection do
      get 'pendentes'
    end
    member do          # ← apenas isso é novo
      get  'responder'
      post 'submeter'
    end
  end
end
  root "templates#index"

  resources :templates

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
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  resources :formularios, only: %i[index new create] do
    collection do
      post :preparar
      get :publicar
    end
  end

  get "avaliacoes/pendentes", to: "avaliacoes#index", as: :avaliacoes_pendentes
end

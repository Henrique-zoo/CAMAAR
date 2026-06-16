Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :avaliacoes, only: [] do
    collection do
      get 'pendentes'
    end
    member do          
      get  'responder'
      post 'submeter'
    end
  end
  resources :formularios do
    member do
      get 'exportar_csv'
    end
  end
end
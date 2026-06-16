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
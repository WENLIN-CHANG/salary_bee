Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :users, only: [ :new, :create ]

  get "dashboard", to: "dashboard#index"

  resources :companies do
    resources :employees do
      member do
        patch :activate
      end

      collection do
        get :bulk_import
        post :bulk_import
        get :download_template
      end
    end
  end

  resources :payrolls, only: [ :index, :show, :new, :create ] do
    member do
      post :calculate
      post :confirm
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"
  get "welcome", to: "home#index", as: :welcome
end

Rails.application.routes.draw do
  mount Redactor3Rails::Engine => '/redactor3_rails'

  root 'pages#show'

  resources :pages, only: :show do
    resources :articles, only: :show
    resources :events, only: :show do
      resources :orders do
        member do
          post :confirm_reservation
          post :checkout
        end
      end
    end
  end

  get   'manage_order/:order_id/:token', controller: :orders_self_service, action: :edit, as: :manage_order
  patch 'manage_order/:order_id/:token', controller: :orders_self_service, action: :update

  resources :by_titles, only: :show
  post '/user_mails/:page_id', to: 'user_emails#create', as: :user_emails

  namespace :admin, path: 'hcms' do
    root 'pages#index'

    resources :pages do
      resources :articles
      resources :events do
        resources :orders
      end
    end

    resources :move_pages, only: :update
    resources :statistics, only: [:index, :show]

    devise_for :users
  end

  get '*path', to: 'redirections#show', format: false, constraints: lambda { | req |
    req.format.html? && ! req.xhr?
  }
end

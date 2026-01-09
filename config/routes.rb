Rails.application.routes.draw do
  mount Redactor3Rails::Engine => '/redactor3_rails'

  root 'pages#show'

  resources :pages, only: :show do
    resources :articles, only: :show
    resources :events, only: :show do
      resources :orders, except: [:edit, :update] do
        member do
          post :confirm_reservation
        end
        resource :invoice, only: :show
      end
    end
  end

  resources :encounters, only: :show do
    resources :encounter_orders, except: [:edit, :update] do
      resource :invoice, only: :show
    end
  end

  scope 'manage_order/:order_id/:token', controller: :orders_self_service do
    get   '/', action: :edit, as: :manage_order
    patch '/', action: :update
    get   '/stripe_payment_succeeded', action: :stripe_payment_succeeded, as: :stripe_payment_succeeded
    get   '/stripe_payment_cancelled', action: :stripe_payment_cancelled, as: :stripe_payment_cancelled
  end

  resources :events, only: [] do
    resource :waitlist, only: [:show, :new, :create]
  end

  # post 'webhooks/stripe', controller: 'webhooks/stripe', action: :webhook

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

    resources :encounters do
      resources :encounter_orders
    end

    resources :move_pages, only: :update
    resources :statistics, only: [:index, :show]

    devise_for :users
  end

  get '*path', to: 'redirections#show', format: false, constraints: lambda { | req |
    req.format.html? && ! req.xhr?
  }
end

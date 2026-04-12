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

  resources :events, only: [] do
    resource :waitlist, only: [:show, :new, :create]
  end

  resources :encounters, only: :show do
    resources :encounter_orders, except: [:edit, :update] do
      resource :invoice, only: :show, controller: :encounter_invoices
    end
  end

  scope 'manage_order/:order_id/:token', controller: :orders_self_service do
    get   '/', action: :edit, as: :manage_order
    patch '/', action: :update
    get   '/stripe_payment_succeeded', action: :stripe_payment_succeeded, as: :stripe_order_payment_succeeded
    get   '/stripe_payment_cancelled', action: :stripe_payment_cancelled, as: :stripe_order_payment_cancelled
  end

  # Note 'prettified' "manage_encounter" but internally, we're managing an
  # EncounterOrder. The URL helper method and controller names reflect that.
  # These routes are all for the buyer and will include things that show the
  # price paid.
  #
  scope 'manage_encounter/:encounter_order_id/:token', controller: :encounter_orders_self_service do
    get   '/', action: :edit, as: :manage_encounter_order
    patch '/', action: :update
    get   '/stripe_payment_succeeded', action: :stripe_payment_succeeded, as: :stripe_encounter_order_payment_succeeded
    get   '/stripe_payment_cancelled', action: :stripe_payment_cancelled, as: :stripe_encounter_order_payment_cancelled
  end

  # Related to the above is a route just used for sharing to e.g. someone who
  # is receiving the item as a gift. Prices are never shown.
  #
  scope 'your_encounter/:token', controller: :encounter_orders_gifted_service do
    get '/', action: :show, as: :your_encounter_order
  end

  # There's a controller for this to demonstrate the structure needed, but it
  # doesn't do anything useful yet.
  #
  # post 'webhooks/stripe', controller: 'webhooks/stripe', action: :webhook

  # Legacy route deprecated by introduction of slugs.
  #
  resources :by_titles, only: :show

  # Used for the "contact us" form and ad-hoc booking form submissions, or
  # used for the encounter "enquire" form submission, respectively.
  #
  post '/user_mails/:page_id',                   to: 'user_emails#create', as: :user_emails
  post '/user_mails_by_encounter/:encounter_id', to: 'user_emails#create', as: :user_emails_by_encounter

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

    resources :move_pages,      only: :update
    resources :move_encounters, only: :update
    resources :statistics,      only: [:index, :show]

    devise_for :users
  end

  # Used chiefly to manage migrations from other site structures. This route
  # must come after all others.
  #
  get '*path', to: 'redirections#show', format: false, constraints: lambda { | req |
    req.format.html? && ! req.xhr?
  }
end

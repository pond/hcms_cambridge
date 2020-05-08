Rails.application.routes.draw do

  mount Redactor3Rails::Engine => '/redactor3_rails'

  root 'pages#show'

  resources :pages, only: :show do
    resources :articles, only: :show
  end

  resources :by_titles,   only: :show
  resource  :user_emails, only: :create

  namespace :admin, path: 'hcms' do
    root 'pages#index'

    resources :pages do
      resources :articles
      resource :convert_to_blog, only: [:new, :create], controller: 'convert_to_blog'
    end

    resources :move_pages, only: :update

    devise_for :users
  end

end

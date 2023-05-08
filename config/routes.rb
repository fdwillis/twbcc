Rails.application.routes.draw do
  resources :blogs, path: '/blog'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  devise_for :users, path: '/', path_names: { sign_in: 'auth/login', sign_out: 'auth/logout', sign_up: 'auth/sign-up' }, controllers: { registrations: 'registrations', sessions: 'sessions'} do
    get '/auth/logout' => 'sessions#destroy'
  end

  authenticated :user do
    root 'application#profile', as: :authenticated_root
  end

  unauthenticated :user do
    root 'products#index'
  end

  get "/membership", to: 'application#membership', as: 'membership'
  get "/view-on-amazon/:asin/:country", to: 'products#amazon', as: 'amazon'
  get "/list", to: 'application#list', as: 'list'
  get "/loved", to: 'application#loved', as: 'loved'
  get "/analytics", to: 'application#analytics', as: 'analytics'
  get "/commissions/:id", to: 'application#commissions', as: 'commissions'
  get "/profile/:id", to: 'application#profile', as: 'profile'
  get "/how-it-works", to: 'application#how_it_works', as: 'how_it_works'
  get "/new-password-set", to: 'registrations#new_password', as: 'new-password-set'
  get "/checkout/:price/:account", to: 'application#checkout'
  get "/explore/:country", to: 'products#explore'
  get "/explore/", to: 'products#index'
  post "/cancel", to: 'application#cancel', as: 'cancel'
  post "/new-password-set", to: 'registrations#new_password'
  post "/loved", to: 'application#loved'
  post "/list", to: 'application#list'

  resources :products, path: '/product'
  resources :search, path: '/search'

end

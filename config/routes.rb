Rails.application.routes.draw do
  mount Split::Dashboard, at: 'split'
  resources :blogs, path: '/blog'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  devise_for :users, path: '/', path_names: { sign_in: 'auth/login', sign_out: 'auth/logout', sign_up: 'auth/sign-up' }, controllers: { registrations: 'registrations', sessions: 'sessions'} do
    get '/auth/logout' => 'sessions#destroy'
  end

  authenticated :user do
    root 'application#profile', as: :authenticated_root
  end

  unauthenticated :user do
    root 'search#index'
  end

  get "/membership", to: 'application#membership', as: 'membership'
  get "/tracking", to: 'application#tracking', as: 'tracking'
  get "/wishlist", to: 'application#wishlist', as: 'wishlist'
  get "/profile/:id", to: 'application#profile', as: 'profile'
  get "/how-it-works", to: 'application#how_it_works', as: 'how_it_works'
  get "/new-password-set", to: 'registrations#new_password', as: 'new-password-set'
  post "/new-password-set", to: 'registrations#new_password'
  post "/wishlist", to: 'application#wishlist'
  post "/tracking", to: 'application#tracking'

  resources :products, path: '/trending'
  resources :search, path: '/discover'

end

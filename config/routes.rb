Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  devise_for :users, path: '/', path_names: { sign_in: 'auth/login', sign_up: 'auth/sign-up', sign_out: 'auth/logout' }, controllers: { registrations: 'registrations', sessions: 'sessions' } do
    get '/auth/logout' => 'sessions#destroy'
  end

  authenticated :user do
    root 'application#profile', as: :authenticated_root
  end

  unauthenticated :user do
    root 'application#welcome'
  end

  %w[404 422 500 503].each do |code|
    get code, to: 'errors#show', code: code
  end

  get '/membership-card',     to: 'application#membership_card',    as: 'membership-card'
  get '/discounts', to: 'application#discounts', as: 'discounts' # sprint2
  get '/users', to: 'application#users', as: 'users'
  get '/view-on-amazon/:asin/:country', to: 'products#amazon', as: 'amazon'
  get '/analytics', to: 'application#analytics', as: 'analytics'
  get '/profile/:id', to: 'application#profile', as: 'profile'
  get '/welcome', to: 'application#welcome', as: 'welcome'
  get '/new-password-set', to: 'registrations#new_password', as: 'new-password-set'
  get '/checkout/:price/:account', to: 'application#checkout'
  get '/checkout/:price', to: 'application#checkout'
  get '/display-discount', to: 'application#display_discount', as: 'display_discount'
  get '/update-discount', to: 'application#update_discount', as: 'update_discount'

  post '/inquiry', to: 'application#inquiry', as: 'inquiry' # sprint2
  post '/new-password-set', to: 'registrations#new_password'
  post '/set-password', to: 'registrations#set_password'
  post '/stripe-webhooks' => 'stripe_webhooks#update', as: :stripeWebhooks

  resources :deposits
  resources :sources
end

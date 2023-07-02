Rails.application.routes.draw do

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  devise_for :users, path: '/', path_names: { sign_in: 'auth/login', sign_out: 'auth/logout' }, controllers: { registrations: 'registrations', sessions: 'sessions'} do
    get '/auth/logout' => 'sessions#destroy'
  end

  authenticated :user do
    root 'application#profile', as: :authenticated_root
  end

  unauthenticated :user do
    root 'application#welcome'
  end

  %w( 404 422 500 503 ).each do |code|
    get code, :to => "errors#show", :code => code
  end
  
  get "/discounts", to: 'application#discounts', as: 'discounts' # sprint2
  get "/membership", to: 'application#membership', as: 'membership'
  get "/auto-trading", to: 'application#autotrading', as: 'autotrading'
  get "/view-on-amazon/:asin/:country", to: 'products#amazon', as: 'amazon'
  get "/list", to: 'application#list', as: 'list'
  get "/loved", to: 'application#loved', as: 'loved'
  get "/analytics", to: 'application#analytics', as: 'analytics'
  get "/commissions/:id", to: 'application#commissions', as: 'commissions'
  get "/profile/:id", to: 'application#profile', as: 'profile'
  get "/welcome", to: 'application#welcome', as: 'welcome'
  get "/new-password-set", to: 'registrations#new_password', as: 'new-password-set'
  get "/checkout/:price/:account", to: 'application#checkout'
  get "/checkout/:price", to: 'application#checkout'
  get "/product/:asin", to: 'products#show'
  get "/split-session", to: 'application#split_session', as: 'split_session'
  get "/display-discount", to: 'application#display_discount', as: 'display_discount'
  get "/update-discount", to: 'application#update_discount', as: 'update_discount'
  get "/questions", to: 'application#questions', as: 'questions'
  get "/trading", to: 'registrations#trading', as: 'trading'
  get "/trade-history", to: 'tradingview#trading_history', as: 'trading_history'

  post "/trading", to: 'registrations#trading'
  post "/signals", to: 'tradingview#signals', as: 'signals' # sprint2
  post "/manage-trading-keys", to: 'tradingview#manage_trading_keys', as: 'manage_trading_keys' # sprint2
  post "/inquiry", to: 'application#inquiry', as: 'inquiry' # sprint2
  post "/activate", to: 'categories#activate'
  post "/search", to: 'search#index'
  post "/cancel", to: 'application#cancel', as: 'cancel'
  post "/new-password-set", to: 'registrations#new_password'
  post "/loved", to: 'application#loved'
  post "/list", to: 'application#list'
  post '/stripe-webhooks' => "stripe_webhooks#update", as: :stripeWebhooks

  resources :blogs, path: '/blog'
  resources :products, path: '/product'
  resources :categories, path: '/categories'
  resources :brands, path: '/brands'
  resources :search, path: '/search'



end

Rails.application.routes.draw do
  # Health check endpoint for load balancer
  get '/health', to: 'application#health'
  
  # Counter routes (to be implemented)
  root 'counters#index'
  resources :counters, only: [:index, :create, :show]
  
  # API routes for counter updates
  namespace :api do
    namespace :v1 do
      resources :counters, only: [:show, :update]
    end
  end
end
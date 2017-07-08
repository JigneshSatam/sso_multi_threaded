Rails.application.routes.draw do
  get 'sessions/new'

  get 'sessions/create'

  get 'sessions/destroy'

  root "users#new"

  get "/thread_safety/index"

  get "/thread_safety/simple"

  get "/thread_safety/infinite"

  get "/login" => "sessions#new"

  post "/login" => "sessions#create"

  delete "/logout" => "sessions#destroy"

  resources :users

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end

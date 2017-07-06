Rails.application.routes.draw do
  get 'users/new'

  root "thread_safety#index"

  get "/thread_safety/index"

  get "/thread_safety/simple"

  get "/thread_safety/infinite"
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end

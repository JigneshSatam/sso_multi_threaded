Rails.application.routes.draw do
  resources :authentications do
    collection do
      post 'login'
      delete 'logout'
    end
  end
  get "/unauthenticated" => "application#unauthenticated"

  root "users#new"

  get "/thread_safety/index"

  get "/thread_safety/simple"

  get "/thread_safety/infinite"

  resources :users

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end

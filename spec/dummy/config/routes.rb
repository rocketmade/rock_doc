Rails.application.routes.draw do
  namespace :api do
    resources :characters
    resources :works
    resources :quotes
  end
end

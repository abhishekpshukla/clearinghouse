require 'api'

Rails.application.routes.draw do

  mount Clearinghouse::API => "/"

  as :user do
    patch '/user/confirmation' => 'confirmations#update', :via => :patch, :as => :update_user_confirmation
  end
  devise_for :users, :controllers => { :confirmations => "confirmations" }

  get 'check_session' => 'users#check_session'
  get 'touch_session' => 'users#touch_session'

  resources :open_capacities

  resources :provider_relationships, :except => :index do
    post 'activate'
  end

  resources :providers do
    member do
      get  'keys'
      post 'reset_keys'
    end
    resources :services, :except => [ :index, :show, :destroy ] do
      resources :eligibility_requirements, shallow: true
    end
  end

  resources :trip_tickets do
    get 'claim_multiple', :on => :collection
    post 'create_multiple_claims', :on => :collection
    get 'clear_filters', :on => :collection
    get 'apply_filters', :on => :collection
    post 'search', :on => :collection    
    member do
      post 'rescind'
    end

    resources :trip_claims do
      member do
        post 'approve'
        post 'decline'
        post 'rescind'
        get 'popup_info'
      end
    end
    
    resources :trip_ticket_comments

    resource :trip_result

    resources :audits, :only => [ :index ]
  end

  resources :users do
    post 'activate', :on => :member
    post 'deactivate', :on => :member
  end

  resources :filters

  resources :bulk_operations, :only => [ :index, :show, :new, :create ] do
    member do
      get 'download'
    end
  end

  resources :reports, :only => [ :index, :show ]

  match 'admin', :via => :get, :controller => :admin, :action => :index
  match 'job_queue' => DelayedJobWeb, :anchor => false, via: [:get, :post], :constraints => lambda { |request|
    request.env['warden'].authenticated? # are we authenticated?
    request.env['warden'].authenticate! # authenticate if not already
    request.env['warden'].user.has_admin_role? # Ensure site_admin role
  }
  match 'preferences', :via => :get, :controller => :users, :action => :preferences

  resource :application_settings, :only => [ :edit, :update ] do
    collection do
      get :index
    end
  end

  get "pages/credits"
  
  root :to => 'trip_tickets#index'
end

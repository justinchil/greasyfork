require 'sidekiq/web'

Rails.application.routes.draw do
  authenticate :user, ->(user) { user.administrator? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  get '/forum', to: redirect('/discussions'), status: 301

  scope '(:locale)', locale: /ar|bg|cs|da|de|el|en|es|fi|fr|fr-CA|he|hu|id|it|ja|ko|nb|nl|eo|pl|pt-BR|ro|ru|sk|sr|sv|th|tr|uk|ug|vi|zh-CN|zh-TW/ do
    get '/users', to: 'users#index', as: 'users'
    get '/users/webhook-info', to: 'users#webhook_info', as: 'user_webhook_info'
    post 'users/webhook-info', to: 'users#webhook_info'
    get '/users/edit_sign_in' => 'users#edit_sign_in', :as => 'user_edit_sign_in'
    delete '/users/identities' => 'users#delete_identity', :as => 'user_delete_identity'
    put '/users/identities' => 'users#update_identity', :as => 'user_update_identity'
    put '/users/remove_password' => 'users#remove_password', :as => 'user_remove_password'
    put '/users/update_password' => 'users#update_password', :as => 'user_update_password'
    get '/users/delete_info' => 'users#delete_info', :as => 'user_delete_info'
    post '/users/delete_start' => 'users#delete_start', :as => 'user_delete_start'
    get '/users/delete_confirm' => 'users#delete_confirm', :as => 'user_delete_confirm'
    post '/users/delete_complete' => 'users#delete_complete', :as => 'user_delete_complete'
    post '/dismiss_announcement/:key' => 'users#dismiss_announcement', as: 'dismiss_announcement'

    # disable destroying users
    devise_for :users, skip: :registrations, controllers: { sessions: 'sessions' }
    devise_scope :user do
      resource :registration,
               only: [:new, :create, :edit, :update],
               path: 'users',
               path_names: { new: 'sign_up' },
               controller: :registrations,
               as: :user_registration do
        get :cancel
      end
    end
    devise_scope :user do
      # a GET path for logging out for use with the forum
      get '/users/sign_out' => 'sessions#destroy'
      get '/auth/:provider/callback', to: 'sessions#omniauth_callback', as: 'omniauth_callback'
      # BrowserID POSTs
      post '/auth/:provider/callback', to: 'sessions#omniauth_callback'
      get '/auth/failure', to: 'sessions#omniauth_failure'
      get '/auth/failure2', to: 'sessions#omniauth_failure'
      post '/users/send_confirmation_email' => 'users#send_confirmation_email'
    end

    root to: 'home#index'

    get 'scripts/sync_additional_info_form', to: 'scripts#sync_additional_info_form', as: 'script_sync_additional_info_form'
    resources :scripts, only: [:index, :show] do
      member do
        # Deprecated after https://github.com/JasonBarnabe/greasyfork/issues/76
        get 'code.meta.js', to: 'scripts#meta_js', locale: nil
        get 'code.user.js', to: 'scripts#user_js', locale: nil

        match 'code/:name.user.js', to: 'scripts#user_js', as: 'user_js', locale: nil, via: [:get, :options]
        match 'code/:name.user.css', to: 'scripts#user_css', as: 'user_css', locale: nil, via: [:get, :options]
        match 'code/:name.js', to: 'scripts#user_js', as: 'library_js', locale: nil, via: [:get, :options]
        match 'code/:name.meta.js', to: 'scripts#meta_js', as: 'meta_js', locale: nil, via: [:get, :options]
        match 'code/:name.meta.css', to: 'scripts#meta_css', as: 'meta_css', locale: nil, via: [:get, :options]

        get 'admin'
        get 'code(.:format)', to: 'scripts#show_code', as: 'show_code', constraints: { format: /.*/ }
        get 'derivatives'
        get 'diff', constraints: ->(req) { req.params[:v1].present? && req.params[:v2].present? }
        get 'feedback'
        get 'stats'

        post 'install-ping', locale: nil

        post 'mark'

        get 'delete'
        post 'delete', to: 'scripts#do_delete', as: 'do_delete'
        post 'undelete', to: 'scripts#do_undelete', as: 'do_undelete'
        post 'request_permanent_deletion'
        post 'unrequest_permanent_deletion'
        post 'do_permanent_deletion', to: 'scripts#do_permanent_deletion', as: 'do_permanent_deletion'
        post 'reject_permanent_deletion', to: 'scripts#reject_permanent_deletion', as: 'reject_permanent_deletion'
        patch 'approve'

        patch 'sync_update'
        patch 'update_promoted'
        patch 'update_locale'
        post 'invite'
        get 'accept_invitation'
        post 'remove_author'
        post 'request_duplicate_check'
      end

      collection do
        get 'by-site(.:format)', action: 'by_site', as: 'site_list'
        # :site can contain a dot, make sure site doesn't eat format or vice versa
        get 'by-site/:site(.:format)', action: 'index', as: 'by_site', constraints: { site: /.*?/, format: /|html|atom|json|jsonp/ }
        get 'reported_not_adult(.:format)', action: 'reported_not_adult', as: 'reported_not_adult'
        get 'libraries(.:format)', action: 'libraries', as: 'libraries'
        get 'search(.:format)', action: 'search', as: 'search'
        get 'code-search(.:format)', action: 'code_search', as: 'code_search'
      end

      resources :script_versions, only: [:create, :new, :index], path: 'versions' do
        get 'delete(.:format)', to: 'script_versions#delete', as: 'delete'
        post 'delete(.:format)', to: 'script_versions#do_delete', as: 'do_delete'
      end

      resources :discussions, only: [:show, :create, :show, :destroy] do
        member do
          post :subscribe
          post :unsubscribe
        end
        resources :comments, only: [:create, :destroy, :update]
      end
    end
    resources :script_versions, only: [:create, :new]
    get 'script_versions/additional_info_form', to: 'script_versions#additional_info_form', as: 'script_version_additional_info_form'
    get 'script_versions/confirm_new_author', to: 'script_versions#confirm_new_author', as: 'script_version_confirm_new_author'
    resources :users, only: :show do
      post 'webhook'
      resources :script_sets, only: [:create, :new, :edit, :update, :destroy], path: 'sets'
      get 'ban', to: 'users#ban', as: 'ban'
      post 'ban', to: 'users#do_ban', as: 'do_ban'
      resources :conversations, only: [:new, :create, :show, :index] do
        resources :messages, only: :create
        member do
          post :subscribe
          post :unsubscribe
        end
      end
      member do
        get :notifications
        patch :update_notifications
        patch :unsubscribe_all
      end
    end
    post 'script_sets/add_to_set', to: 'script_sets#add_to_set', as: 'add_to_script_set'

    resources :discussions, path: 'discussions/:category', category: /greasyfork|development|requests|script-discussions|no-scripts|moderators/, only: [:index, :show, :destroy], as: 'category_discussion' do
      member do
        post :subscribe
        post :unsubscribe
      end
      resources :comments, only: [:create, :destroy, :update]
    end

    resources :discussions, only: [:index, :new, :create] do
      collection do
        post :mark_all_read
      end
    end

    get 'import', to: 'import#index', as: 'import_start'
    post 'import/add', to: 'import#add', as: 'import_add'
    get 'import/url', to: 'import#url', as: 'import_url'

    get 'help', to: 'help#index', as: 'help'
    get 'help/allowed-markup', to: 'help#allowed_markup', as: 'help_allowed_markup'
    get 'help/code-rules', to: 'help#code_rules', as: 'help_code_rules'
    get 'help/contact', to: 'help#contact', as: 'help_contact'
    get 'help/credits', to: 'help#credits', as: 'help_credits'
    get 'help/external-scripts', to: 'help#external_scripts', as: 'help_external_scripts'
    get 'help/installing-user-scripts', to: 'help#installing_user_scripts', as: 'help_installing_user_scripts'
    get 'help/installing-user-styles', to: 'help#installing_user_styles', as: 'help_installing_user_styles'
    get 'help/writing-user-scripts', to: 'help#writing_user_scripts', as: 'help_writing_user_scripts'
    get 'help/rewriting', to: 'help#rewriting', as: 'help_rewriting'
    get 'help/meta-keys', to: 'help#meta_keys', as: 'help_meta_keys'
    get 'help/privacy', to: 'help#privacy', as: 'help_privacy'
    get 'help/user-js-conversions', to: 'help#user_js_conversions', as: 'help_user_js_conversions'

    post 'preview-markup', to: 'home#preview_markup', as: 'preview_markup'
    get 'search', to: 'home#search'

    resources :moderator_actions, only: [:index]

    get 'opensearch.xml', to: 'opensearch#description', as: 'opensearch_description'

    resources :reports, only: [:new, :create, :index, :show] do
      member do
        post :dismiss
        post :uphold
        post :rebut
      end
    end

    namespace :admin do
      get '/' => 'home#index'
      resources :ads, only: [] do
        member do
          patch :approve
          patch :reject
        end
        collection do
          get :pending
        end
      end
      resource :analytics_stats, only: [:show, :update]
      resources :allowed_requires, only: [:new, :create, :edit, :update, :destroy]
      resources :blocked_script_codes, only: [:index, :new, :create, :edit, :update, :destroy]
      resources :blocked_script_texts, only: [:index, :new, :create, :edit, :update, :destroy]
      resources :blocked_script_urls, only: [:index, :new, :create, :edit, :update, :destroy]
      resources :redirect_service_domains, only: [:index, :new, :create, :edit, :update, :destroy]
      resources :script_similarities, only: :index
      resources :spammy_email_domains, only: [:index, :new, :create, :edit, :update, :destroy]
    end

    get '/forum', to: redirect('/%{locale}/discussions'), status: 301
    get '/forum/discussion/:id' => 'discussions#old_redirect'
    get '/forum/discussion/comment/:id' => 'comments#old_redirect'
    get '/forum/discussion/:id/:slug' => 'discussions#old_redirect'

    get '404', to: 'home#routing_error'
  end

  get '/forum/discussion/:id' => 'discussions#old_redirect'
  get '/forum/discussion/comment/:id' => 'comments#old_redirect'
  get '/forum/discussion/:id/:slug' => 'discussions#old_redirect'

  get '404', to: 'home#routing_error'
end

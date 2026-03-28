Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Static content
  get "getting-started" => "pages#getting_started"
  get "getting-started.md" => "pages#getting_started_md"
  get "SKILL.md" => "pages#skill_md"
  get "skill.md" => "pages#skill_md"

  # Web UI
  root "home#index"
  get "search" => "search#index"

  # API v1
  namespace :api do
    namespace :v1 do
      post "users", to: "users#create"
      get "users/:username", to: "users#show", as: :user
      get "users/:username/repos", to: "users#repos", as: :user_repos
      get "whoami", to: "users#whoami"

      post "repos", to: "repos#create"
      get "repos/search", to: "repos#search"
      get "repos/:owner/:name", to: "repos#show", as: :repo, constraints: { name: /[^\/]+/ }
      post "repos/:owner/:name/star", to: "stars#create", constraints: { name: /[^\/]+/ }
      delete "repos/:owner/:name/star", to: "stars#destroy", constraints: { name: /[^\/]+/ }
    end
  end

  # Owner + repo pages (must come after static routes)
  get ":owner", to: "owners#show", as: :owner,
    constraints: { owner: /(?!api|git|search|getting-started)[a-z0-9\-_]+/ }
  get ":owner/:repo", to: "repos#show", as: :repo_page,
    constraints: { owner: /(?!api|git|search|getting-started)[a-z0-9\-_]+/, repo: /[a-z0-9\-_\.]+/ }
end

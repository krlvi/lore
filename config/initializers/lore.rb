module Lore
  mattr_accessor :repo_root

  self.repo_root = ENV.fetch("LORE_REPO_ROOT") {
    Rails.root.join("storage", "repos", Rails.env).to_s
  }
end

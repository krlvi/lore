#!/usr/bin/env ruby
# End-to-end demo validation script
# Run with: bundle exec rails runner script/validate_demo.rb

failures = []

def check(label, &block)
  result = block.call
  if result
    puts "  ✅ #{label}"
  else
    puts "  ❌ #{label}"
    $failures ||= []
    $failures << label
  end
rescue => e
  puts "  ❌ #{label}: #{e.message}"
  $failures ||= []
  $failures << "#{label}: #{e.message}"
end

puts "=== Lore Demo Validation ==="
puts

# --- User registration ---
puts "1. User Registration"
u = User.create!(username: "validate-user-#{SecureRandom.hex(4)}", email: "validate-#{SecureRandom.hex(4)}@test.com")
token = u.raw_pat
check("User created") { u.persisted? }
check("PAT token present") { token.present? }
check("PAT authenticates") { u.authenticate_pat(token) }
check("Wrong token rejected") { !u.authenticate_pat("wrong") }

# --- Repo creation ---
puts "\n2. Repo Creation"
repo_root = Rails.application.config.lore_repo_root
disk_path = File.join(repo_root, u.username, "validate-tool.git")
repo = Repo.create!(
  owner: u.username, name: "validate-tool",
  description: "Validation test repo", tags: "test,validate",
  disk_path: disk_path
)
check("Repo created") { repo.persisted? }
check("Bare repo on disk") { Dir.exist?(disk_path) }
check("HEAD points to main") { File.read(File.join(disk_path, "HEAD")).include?("main") }
check("clone_url correct") { repo.clone_url.include?("/git/#{u.username}/validate-tool.git") }
check("web_url correct") { repo.web_url.include?("/#{u.username}/validate-tool") }

# --- Search ---
puts "\n3. Search"
Repo.find_each(&:update_embedding!)
results = Repo.search("send slack notification", limit: 5)
check("Search returns results") { results.length > 0 }
check("slack-notify is top result") { results.first&.dig(:repo)&.name == "slack-notify" }
check("Results have scores") { results.all? { |r| r[:score].is_a?(Numeric) } }

# --- Stars ---
puts "\n4. Stars"
slack_repo = Repo.find_by(owner: "lore-agent", name: "slack-notify")
if slack_repo
  initial_stars = slack_repo.stars_count
  star = Star.create!(user: u, repo: slack_repo)
  slack_repo.reload
  check("Star created") { star.persisted? }
  check("Star count incremented") { slack_repo.stars_count == initial_stars + 1 }
  star.destroy!
  slack_repo.reload
  check("Unstar decrements count") { slack_repo.stars_count == initial_stars }
else
  check("slack-notify repo exists for starring") { false }
end

# --- Demo scenario ---
puts "\n5. Demo Scenario (Slack search/clone/use)"
check("lore-agent/slack-notify exists") { Repo.exists?(owner: "lore-agent", name: "slack-notify") }
slack = Repo.find_by(owner: "lore-agent", name: "slack-notify")
check("slack-notify has description") { slack&.description.present? }
check("slack-notify has tags") { slack&.tags_array&.any? }
check("slack-notify has ≥25 stars") { (slack&.stars_count || 0) >= 25 }
check("Searching 'slack' returns it") {
  r = Repo.search("slack", limit: 5)
  r.any? { |x| x[:repo].name == "slack-notify" }
}
check("Searching 'webhook notification' returns it") {
  r = Repo.search("webhook notification", limit: 5)
  r.any? { |x| x[:repo].name == "slack-notify" }
}

# --- Summary ---
puts
$failures ||= []
if $failures.empty?
  puts "=== ALL VALIDATIONS PASSED ✅ ==="
else
  puts "=== #{$failures.length} FAILURES ❌ ==="
  $failures.each { |f| puts "  - #{f}" }
  exit 1
end

# Demo seeds for Lore hackathon MVP
puts "Seeding demo data..."

repo_root = Rails.application.config.lore_repo_root
FileUtils.mkdir_p(repo_root)

# Create demo user: lore-agent
agent_user = User.find_or_initialize_by(username: "lore-agent")
unless agent_user.persisted?
  agent_user.save!
  puts "Created user: lore-agent (token: #{agent_user.raw_pat})"
else
  puts "User lore-agent already exists"
end

# Helper: create a repo with realistic data and commits
def seed_repo(owner:, name:, description:, tags:, readme:, stars: 0, last_pushed_days_ago: nil)
  repo_root = Rails.application.config.lore_repo_root
  disk_path = File.join(repo_root, owner, "#{name}.git")

  repo = Repo.find_or_initialize_by(owner: owner, name: name)
  if repo.new_record?
    repo.description = description
    repo.tags = tags.join(",")
    repo.disk_path = disk_path
    repo.save!
    puts "Created repo: #{owner}/#{name}"
  else
    puts "Repo already exists: #{owner}/#{name}"
    # Update description/tags in case they changed
    repo.update(description: description, tags: tags.join(","))
  end

  # Ensure the bare repo exists
  unless Dir.exist?(disk_path)
    FileUtils.mkdir_p(File.dirname(disk_path))
    system("git init --bare #{disk_path} -q")
    File.write(File.join(disk_path, "HEAD"), "ref: refs/heads/main\n")
  end

  # Seed a commit with the README if repo is empty
  begin
    `git --git-dir=#{Shellwords.escape(disk_path)} rev-parse HEAD 2>&1`
    is_empty = !$?.success?
  rescue
    is_empty = true
  end

  if is_empty
    Dir.mktmpdir do |tmpdir|
      work = "#{tmpdir}/work"
      system("git clone --quiet #{Shellwords.escape(disk_path)} #{Shellwords.escape(work)} 2>/dev/null || true")
      unless Dir.exist?("#{work}/.git")
        Dir.mkdir(work)
        Dir.chdir(work) { system("git init -q && git remote add origin #{Shellwords.escape(disk_path)}") }
      end
      Dir.chdir(work) do
        system("git config user.email 'agent@lore.example.com'")
        system("git config user.name 'lore-agent'")
        File.write("README.md", readme)
        system("git add README.md")
        system("git commit -q -m 'Initial commit: add #{name}'")
        system("git branch -M main 2>/dev/null || git checkout -b main 2>/dev/null || true")
        system("git push --quiet origin main 2>/dev/null")
      end
    end
    pushed_at = Time.current - (last_pushed_days_ago || 1).days
    repo.update_column(:last_pushed_at, pushed_at)
    puts "  Seeded commit for #{owner}/#{name}"
  end

  # Set star count
  repo.update_column(:stars_count, stars) if stars > 0

  # Generate embedding
  repo.update_embedding!
  repo
end

# ---- DEMO REPOS ----

seed_repo(
  owner: "lore-agent",
  name: "slack-notify",
  description: "Posts a message to a Slack webhook. Input: SLACK_WEBHOOK_URL, MESSAGE.",
  tags: %w[slack webhook notification messaging],
  stars: 34,
  last_pushed_days_ago: 3,
  readme: <<~README
    # slack-notify

    Posts a message to a Slack webhook.

    ## What it does

    Sends a message to any Slack channel via an incoming webhook URL.

    ## Inputs

    | Name | Description | Required |
    |------|-------------|----------|
    | SLACK_WEBHOOK_URL | Slack incoming webhook URL | Yes |
    | MESSAGE | Message text to send | Yes |
    | EMOJI | Custom emoji prefix (default: :robot_face:) | No |

    ## Outputs

    Exit code 0 on success. Non-zero on failure.

    ## Usage

    ```bash
    SLACK_WEBHOOK_URL=https://hooks.slack.com/services/... \\
      MESSAGE="Deployment finished!" \\
      bash slack-notify.sh
    ```

    ## Dependencies

    - curl

    ## Script

    ```bash
    #!/bin/bash
    set -e
    : "${SLACK_WEBHOOK_URL:?required}"
    : "${MESSAGE:?required}"
    EMOJI="${EMOJI:-:robot_face:}"
    curl -sf -X POST "$SLACK_WEBHOOK_URL" \\
      -H 'Content-type: application/json' \\
      -d "{\"text\": \"$EMOJI $MESSAGE\"}"
    ```
  README
)

seed_repo(
  owner: "lore-agent",
  name: "send-email",
  description: "Sends an email via SMTP. Input: TO, SUBJECT, BODY, SMTP_HOST.",
  tags: %w[email smtp notification messaging],
  stars: 19,
  last_pushed_days_ago: 5,
  readme: <<~README
    # send-email

    Sends an email via SMTP.

    ## Inputs

    | Name | Description | Required |
    |------|-------------|----------|
    | TO | Recipient email address | Yes |
    | SUBJECT | Email subject | Yes |
    | BODY | Email body text | Yes |
    | SMTP_HOST | SMTP server hostname | Yes |
    | SMTP_PORT | SMTP port (default: 587) | No |
    | SMTP_USER | SMTP username | No |
    | SMTP_PASS | SMTP password | No |

    ## Usage

    ```bash
    TO=user@example.com SUBJECT="Hello" BODY="World" SMTP_HOST=smtp.gmail.com bash send-email.sh
    ```

    ## Dependencies

    - curl with SMTP support
  README
)

seed_repo(
  owner: "lore-agent",
  name: "fetch-url",
  description: "Fetches a URL and returns the response body as text. Input: URL.",
  tags: %w[http fetch scraping request],
  stars: 21,
  last_pushed_days_ago: 7,
  readme: <<~README
    # fetch-url

    Fetches a URL and returns the response body.

    ## Inputs

    | Name | Description | Required |
    |------|-------------|----------|
    | URL | URL to fetch | Yes |
    | HEADERS | Extra headers (key:value, comma-separated) | No |
    | METHOD | HTTP method (default: GET) | No |

    ## Usage

    ```bash
    URL=https://api.example.com/data bash fetch-url.sh
    ```
  README
)

seed_repo(
  owner: "lore-agent",
  name: "parse-json",
  description: "Reads a JSON file or stdin and extracts a value by key path. Input: FILE or stdin, KEY_PATH.",
  tags: %w[json parsing data extraction],
  stars: 16,
  last_pushed_days_ago: 12,
  readme: <<~README
    # parse-json

    Reads JSON and extracts values by key path using jq.

    ## Inputs

    | Name | Description | Required |
    |------|-------------|----------|
    | KEY_PATH | jq-style key path e.g. .user.name | Yes |
    | FILE | JSON file path (or use stdin) | No |

    ## Usage

    ```bash
    KEY_PATH='.user.name' FILE=data.json bash parse-json.sh
    cat data.json | KEY_PATH='.user.name' bash parse-json.sh
    ```
  README
)

seed_repo(
  owner: "lore-agent",
  name: "git-summary",
  description: "Generates a human-readable summary of recent commits in a git repo.",
  tags: %w[git summarize reporting changelog],
  stars: 28,
  last_pushed_days_ago: 2,
  readme: <<~README
    # git-summary

    Generates a human-readable summary of recent git commits.

    ## Inputs

    | Name | Description | Required |
    |------|-------------|----------|
    | REPO_PATH | Path to the git repo (default: .) | No |
    | SINCE | Date to look back from (default: 7 days ago) | No |

    ## Usage

    ```bash
    REPO_PATH=/path/to/repo SINCE="2 weeks ago" bash git-summary.sh
    ```
  README
)

puts "\nSeeding complete!"
puts "Total repos: #{Repo.count}"
puts "Try: lore search 'send slack notification'"

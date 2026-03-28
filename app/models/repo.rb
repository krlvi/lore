class Repo < ApplicationRecord
  has_many :stars, dependent: :destroy
  has_many :stargazers, through: :stars, source: :user

  validates :owner, presence: true, format: { with: /\A[a-z0-9\-_]+\z/ }
  validates :name, presence: true, format: { with: /\A[a-z0-9\-_\.]+\z/ }
  validates :owner, uniqueness: { scope: :name }
  validates :disk_path, presence: true

  after_create :initialize_bare_repo

  def web_url(base_url: nil)
    host = base_url || ENV.fetch("LORE_HOST", Lore::Application.config.lore_base_url)
    "#{host}/#{owner}/#{name}"
  end

  def clone_url(base_url: nil)
    host = base_url || ENV.fetch("LORE_HOST", Lore::Application.config.lore_base_url)
    "#{host}/git/#{owner}/#{name}.git"
  end

  def tags_array
    return [] if tags.blank?
    tags.split(",").map(&:strip).reject(&:blank?)
  end

  def tags_array=(arr)
    self.tags = arr.join(",")
  end

  # Cosine similarity search using stored embedding
  def self.search(query, limit: 20)
    return all.order(stars_count: :desc).limit(limit) if query.blank?

    query_vec = EmbeddingService.embed(query)
    scored = all.map do |repo|
      next nil if repo.embedding.blank?
      stored = JSON.parse(repo.embedding) rescue nil
      next nil if stored.nil?
      score = cosine_similarity(query_vec, stored)
      { repo: repo, score: score }
    end.compact

    scored.sort_by { |s| -s[:score] }.first(limit).map { |s| s.merge(repo: s[:repo]) }
  end

  def self.cosine_similarity(a, b)
    return 0.0 if a.empty? || b.empty? || a.size != b.size
    dot = a.zip(b).sum { |x, y| x * y }
    mag_a = Math.sqrt(a.sum { |x| x * x })
    mag_b = Math.sqrt(b.sum { |x| x * x })
    return 0.0 if mag_a.zero? || mag_b.zero?
    dot / (mag_a * mag_b)
  end

  def update_embedding!
    text = [ name, description, tags ].compact.join(" ")
    vec = EmbeddingService.embed(text)
    update_column(:embedding, vec.to_json)
  end

  private

  def initialize_bare_repo
    return if disk_path.blank?
    return if Dir.exist?(disk_path)
    FileUtils.mkdir_p(File.dirname(disk_path))
    system("git", "init", "--bare", disk_path)
    # Point HEAD at main
    File.write(File.join(disk_path, "HEAD"), "ref: refs/heads/main\n")
    # Reject non-fast-forward pushes to main
    system("git", "-C", disk_path, "config", "receive.denyNonFastForwards", "true")
    system("git", "-C", disk_path, "config", "receive.denyDeletes", "true")
  end
end

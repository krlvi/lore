class User < ApplicationRecord
  has_many :stars, dependent: :destroy
  has_many :starred_repos, through: :stars, source: :repo

  validates :username, presence: true, uniqueness: true,
            format: { with: /\A[a-z][a-z0-9\-]*\z/, message: "must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens" }
  validates :pat_digest, presence: true

  # Generate a PAT on create. Returns the raw token only once (not stored).
  attr_accessor :raw_pat

  before_validation :generate_pat, on: :create

  def authenticate_pat(token)
    BCrypt::Password.new(pat_digest).is_password?(token)
  rescue BCrypt::Errors::InvalidHash
    false
  end

  private

  def generate_pat
    self.raw_pat = "lore_pat_#{SecureRandom.hex(24)}"
    self.pat_digest = BCrypt::Password.create(raw_pat, cost: BCrypt::Engine::MIN_COST)
  end
end

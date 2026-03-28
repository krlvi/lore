# Simple TF-IDF-style embedding for semantic search.
# Uses a vocabulary built from all repo texts and computes a sparse vector.
# For demo purposes this provides reasonable keyword similarity.
# Can be replaced with an LLM embedding API for production.
class EmbeddingService
  VECTOR_SIZE = 512

  def self.embed(text)
    return Array.new(VECTOR_SIZE, 0.0) if text.blank?

    tokens = tokenize(text)
    return Array.new(VECTOR_SIZE, 0.0) if tokens.empty?

    vec = Array.new(VECTOR_SIZE, 0.0)
    tokens.each do |token|
      idx = stable_hash(token) % VECTOR_SIZE
      # Use subword-like weighting: longer tokens get more weight
      weight = Math.log(token.length + 1) + 1.0
      vec[idx] += weight
    end

    # L2 normalize
    mag = Math.sqrt(vec.sum { |x| x * x })
    return vec if mag.zero?
    vec.map { |x| x / mag }
  end

  private

  def self.tokenize(text)
    text.downcase
        .gsub(/[^a-z0-9\s\-_]/, " ")
        .split(/[\s\-_]+/)
        .reject { |t| t.length < 2 }
        .flat_map { |t| expand_token(t) }
  end

  # Generate token + bigrams for better matching
  def self.expand_token(token)
    result = [ token ]
    # Add character bigrams for fuzzy matching
    if token.length >= 4
      (0...token.length - 1).each do |i|
        result << token[i, 2]
      end
    end
    result
  end

  def self.stable_hash(str)
    # FNV-1a hash - deterministic across runs
    hash = 2166136261
    str.each_byte do |byte|
      hash ^= byte
      hash = (hash * 16777619) & 0xFFFFFFFF
    end
    hash
  end
end

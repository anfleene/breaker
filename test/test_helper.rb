require 'bundler/setup'

require 'minitest/autorun'

require 'breaker'
require 'active_support'

module Rails
  def self.cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end

  def self.clear_cache
    @cache = nil
  end
end


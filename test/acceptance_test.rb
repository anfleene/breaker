require_relative 'test_helper'
require_relative 'test_cases'
require 'breaker/rails_cache/repo'

class AcceptanceTest < MiniTest::Unit::TestCase
  include Breaker::TestCases

  attr_reader :fuse, :repo

  def setup
    @repo = Breaker::RailsCache::Repo.new
    @fuse = Breaker::RailsCache::Fuse.new :test
    super
  end
end

require_relative 'test_helper'
require_relative 'test_cases'
require 'breaker/in_memory_repo'

class AcceptanceTest < MiniTest::Unit::TestCase
  include Breaker::TestCases

  attr_reader :fuse, :repo

  def setup
    @repo = Breaker::InMemoryRepo.new
    @fuse = Breaker::InMemoryRepo::Fuse.new :test
    super
  end
end

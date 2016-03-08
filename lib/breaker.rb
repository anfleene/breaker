require "breaker/version"
require 'sane_timeout'

module Breaker
  CircuitOpenError = Class.new RuntimeError
  MissingRepoError = Class.new RuntimeError

  class << self
    def circuit(name, options = {})
      raise MissingRepoError, "Missing Breaker Repo: example usage 'Breaker.repo = Breaker::InMemoryRepo.new'" unless repo

      fuse = repo.upsert options.merge(name: name)

      circuit = Circuit.new fuse

      if block_given?
        circuit.run do
          yield
        end
      end

      circuit
    end

    def closed?(name)
      circuit(name).closed?
    end
    alias up? closed?

    def open?(name)
      circuit(name).open?
    end
    alias down? open?

    def repo
      @repo
    end

    def repo=(repo)
      @repo = repo
    end

    def callback(name, &block)
      define_singleton_method name do |circuit|
        block.call(circuit)
      end
    end

    def fire_callback(callback_name, circuit)
      send(callback_name, circuit) if respond_to?(callback_name)
    end
  end

  class Circuit
    attr_accessor :fuse

    def callback(callback_name)
      Breaker.fire_callback(callback_name, self)
    end

    def initialize(fuse)
      @fuse = fuse
    end

    def name
      fuse.name
    end

    def open(clock = Time.now)
      callback(:before_open)
      fuse.state = :open
      fuse.retry_threshold = clock + fuse.retry_timeout
      callback(:after_open)
    end

    def close
      callback(:before_close)
      fuse.failure_count = 0
      fuse.state = :closed
      fuse.retry_threshold = nil
      callback(:after_close)
    end

    def ==(other)
      other.instance_of?(self.class) && fuse == other.fuse
    end

    def open?
      fuse.state == :open
    end
    alias down? open?

    def closed?
      [:closed,:disabled].include?(fuse.state)
    end
    alias up? closed?

    def enabled?
      fuse.state != :disabled
    end

    def run(clock = Time.now)
      half_open = half_open?(clock)
      timeout = fuse.timeout
      timeout = fuse.half_open_timeout if half_open
      if closed? || half_open
        begin
          result = SaneTimeout.timeout timeout do
            yield
          end

          close if half_open

          result
        rescue fuse.breaker_error_class => ex
          fuse.failure_count = fuse.failure_count + 1

          open clock if half_open || tripped?

          raise ex
        end
      else
        raise Breaker::CircuitOpenError, "Refusing to run code while circuit #{name} is open"
      end
    end

    private
    def tripped?
      enabled? && fuse.failure_count > fuse.failure_threshold
    end

    def half_open?(clock)
      open? && clock >= fuse.retry_threshold
    end
  end
end

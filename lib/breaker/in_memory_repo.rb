module Breaker
  class InMemoryRepo
    Fuse = Struct.new :name, :state, :failure_threshold, :retry_timeout, :timeout, :half_open_timeout, :failure_count, :retry_threshold, :breaker_error_class do
      def initialize(*args)
        super
        config = InMemoryRepo.config
        self.failure_threshold ||= config[:failure_threshold]
        self.retry_timeout ||= config[:retry_timeout]
        self.timeout ||= config[:timeout]
        self.half_open_timeout ||= config[:half_open_timeout]

        self.state ||= config[:state]
        self.failure_count ||= config[:failure_count]
        self.breaker_error_class ||=  config[:breaker_error_class]
      end

      def ==(other)
        other.instance_of?(self.class) && name == other.name
      end
    end

    attr_reader :store

    def self.config
      {
        failure_threshold: 10,
        retry_timeout: 60,
        timeout: 5,
        half_open_timeout: 0.5,
        breaker_error_class: Timeout::Error,
        failure_count: 0,
        failure_count_ttl: 300,
        state: :closed,
      }
    end

    def initialize
      @store = []
    end

    def upsert(attributes)
      existing = named attributes.fetch(:name)
      if existing
        update existing, attributes
      else
        create attributes
      end
    end

    def count
      store.length
    end

    def first
      store.first
    end

    def named(name)
      store.find { |fuse| fuse.name == name }
    end

    def create(attributes)
      fuse = Fuse.new

      attributes.each_pair do |key, value|
        fuse.send "#{key}=", value
      end

      store << fuse

      fuse
    end

    def update(existing, attributes)
      existing

      attributes.each_pair do |key, value|
        existing.send "#{key}=", value
      end

      existing
    end
  end
end

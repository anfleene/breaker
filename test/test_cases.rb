module Breaker
  module TestCases
    CircuitClosedError = Class.new(StandardError)
    CircuitOpenError = Class.new(StandardError)
    def setup
      Breaker.repo = @repo
    end

    def test_new_fuses_start_off_clean
      circuit = Breaker.circuit 'test'
      fuse = circuit.fuse

      assert circuit.closed?, "New circuits should be closed"
      assert_equal 0, fuse.failure_count
    end

    def test_goes_into_open_state_when_failure_threshold_reached
      circuit = Breaker.circuit 'test', failure_threshold: 5, retry_timeout: 30
      fuse = circuit.fuse

      assert circuit.closed?

      fuse.failure_threshold.times  do
        begin
          circuit.run do
            raise Timeout::Error
          end
        rescue Timeout::Error; end
      end

      assert_equal fuse.failure_count, fuse.failure_threshold
      refute circuit.open?

      assert_raises Timeout::Error do
        circuit.run do
          raise Timeout::Error
        end
      end

      assert circuit.open?

      assert_raises Breaker::CircuitOpenError do
        circuit.run do
          assert false, "Block should not run in this state"
        end
      end
    end

    def test_success_in_half_open_state_moves_circuit_into_closed
      clock = Time.now
      circuit = Breaker.circuit 'test', failure_threshold: 2, retry_timeout: 15
      fuse = circuit.fuse

      (fuse.failure_threshold + 1).times do
        begin
          circuit.run clock do
            raise Timeout::Error
          end
        rescue Timeout::Error ; end
      end

      assert circuit.open?, "Circuit should be Open"

      assert_raises Breaker::CircuitOpenError do
        circuit.run clock do
          # nothing
        end
      end

      circuit.run clock + fuse.retry_timeout do
        # do nothing, this works and flips the circuit back closed
      end

      assert circuit.closed?
    end

    def test_failures_in_half_open_state_push_retry_timeout_back
      clock = Time.now
      circuit = Breaker.circuit 'test', failure_threshold: 1, retry_timeout: 15
      fuse = circuit.fuse

      (fuse.failure_threshold + 1).times do
        begin
          circuit.run clock do
            raise Timeout::Error
          end
        rescue Timeout::Error ; end
      end

      assert circuit.open?, "Circuit should be open"

      assert_raises Timeout::Error do
        circuit.run clock + fuse.retry_timeout do
          raise Timeout::Error
        end
      end

      assert_raises Breaker::CircuitOpenError do
        circuit.run clock + fuse.retry_timeout do
          assert false, "Block should not be run while in this state"
        end
      end

      assert_raises Timeout::Error do
        circuit.run clock + fuse.retry_timeout * 2 do
          raise Timeout::Error
        end
      end
    end

    def test_counts_timeouts_as_trips
      circuit = Breaker.circuit 'test', retry_timeout: 15, timeout: 0.01
      fuse = circuit.fuse
      assert circuit.closed?

      assert_raises TimeoutError do
        circuit.run do
          sleep fuse.timeout * 2
        end
      end
    end

    def test_circuit_factory_persists_fuses
      circuit_a = Breaker.circuit 'test'
      circuit_b = Breaker.circuit 'test'
      fuse_a = circuit_a.fuse
      fuse_b = circuit_b.fuse

      assert_equal circuit_a, circuit_b, "Multiple calls to `circuit` should return the same circuit"

      assert_equal 'test', fuse_a.name
      assert_equal 'test', fuse_b.name
    end

    def test_circuit_factory_creates_new_fuses_with_sensible_defaults
      circuit = Breaker.circuit 'test'
      fuse = circuit.fuse

      assert_equal 10, fuse.failure_threshold, "Failure Theshold should have a default"
      assert_equal 60, fuse.retry_timeout, "Retry timeout should have a default"
      assert_equal 5, fuse.timeout, "Timeout should have a default"
    end

    def test_circuit_factory_updates_existing_fuses
      fuse1 = Breaker.circuit('test').fuse

      fuse2 = Breaker.circuit('test', failure_threshold: 1,
        retry_timeout: 2, timeout: 3).fuse
      assert_equal fuse1, fuse2

      assert_equal 1, fuse2.failure_threshold
      assert_equal 2, fuse2.retry_timeout
      assert_equal 3, fuse2.timeout
    end

    def test_circuit_breaker_factory_can_run_code_through_the_circuit
      assert_raises Timeout::Error do
        Breaker.circuit 'test' do
          raise Timeout::Error
        end
      end
    end

    def test_breaker_query_methods
      circuit = Breaker.circuit 'test'
      circuit.close

      assert Breaker.closed?('test')
      assert Breaker.up?('test')
      refute Breaker.open?('test')
      refute Breaker.down?('test')

      circuit.open

      assert Breaker.open?('test')
      assert Breaker.down?('test')
      refute Breaker.closed?('test')
      refute Breaker.up?('test')
    end

    def test_breaker_callbacks
      Breaker.callback(:after_close) do
        raise CircuitClosedError
      end
      Breaker.callback(:after_open) do
        raise CircuitOpenError
      end

      circuit = Breaker.circuit 'test'
      assert_raises CircuitClosedError do
        circuit.close
      end
      assert_raises CircuitOpenError do
        circuit.open
      end

      # Reset callbacks
      Breaker.callback(:after_close) do
        # Do nothing
      end
      Breaker.callback(:after_open) do
        # Do nothing
      end

    end
  end
end

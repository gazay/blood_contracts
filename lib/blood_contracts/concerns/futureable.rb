if defined?(Concurrent::Future)
  require "concurrent"

  module BloodContracts
    module Concerns
      module Futureable
        def _runner
          @_runner ||= Runner.new(self, context: self)
        end

        def runner
          @runner ||= RunnerFuture.new(_runner)
        end

        # FIXME: track errors in the execution
        class RunnerFuture < SimpleDelegator
          def call(**kwargs)
            Concurrent::Future.execute { __getobj__.call(**kwargs) }
          end
        end
      end
    end
  end
end

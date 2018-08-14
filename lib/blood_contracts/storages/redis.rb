require_relative "./redis/switching.rb"
require_relative "./redis/statistics.rb"
require_relative "./redis/connection.rb"

module BloodContracts
  module Storages
    class Redis < Base
      option :root, default: -> { session }

      include Connection

      def initialize(*)
        redis_loaded?
        self.redis ||= connection
        super
      end

      # FIXME: Get rid of redis-objects ?

      def switching(_switcher)
        Redis::Switching.new(self, redis)
      end

      def statistics(statistics)
        Redis::Statistics.new(self, redis, statistics)
      end

      def redis=(conn)
        Thread.current[:__blood_contracts_redis] =
          ConnectionPoolProxy.proxy_if_needed(conn)
      end

      # rubocop:disable Style/GlobalVars
      def redis
        Thread.current[:__blood_contracts_redis] || $redis || current_redis ||
          raise(
            NotConnected,
            "BloodContracts::Storage:Redis not set to a Redis.new connection"
          )
      end
      # rubocop:enable Style/GlobalVars

      class ConnectionPoolProxy
        def initialize(pool)
          @pool = pool if self.class.should_proxy?(pool)
          raise ArgumentError "Should only proxy ConnectionPool!"
        end

        # rubocop:disable Style/MethodMissing
        def method_missing(name, *args, &block)
          @pool.with { |x| x.send(name, *args, &block) }
        end
        # rubocop:enable Style/MethodMissing

        def respond_to_missing?(name, include_all = false)
          @pool.with { |x| x.respond_to?(name, include_all) }
        end

        def self.should_proxy?(conn)
          defined?(::ConnectionPool) && conn.is_a?(::ConnectionPool)
        end

        def self.proxy_if_needed(conn)
          if should_proxy?(conn)
            ConnectionPoolProxy.new(conn)
          else
            conn
          end
        end
      end
    end
  end
end

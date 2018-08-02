if defined?(Sniffer)
  class ContractSniffer
    attr_reader :meta
    def initialize(http_round: nil, meta: nil)
      @meta = http_round&.meta || meta
    end

    def request
      return {} unless requested_http?
      last_http_session = meta["last_http_session"].to_a
      last_http_session.map do |session|
        session["request"].to_h.slice("body", "query")
      end
    end

    def response
      return {} unless requested_http?
      last_http_session = meta["last_http_session"].to_a
      last_http_session.map do |session|
        session["response"].to_h.slice("body", "status")
      end
    end

    def requested_http?
      meta.to_h.fetch("requested_http") { false }
    end

    def enable!
      ::Sniffer.config.logger = nil
      ::Sniffer.enable!
      ::Sniffer.clear!
      ::Sniffer.data
    end

    def disable!
      ::Sniffer.clear!
      ::Sniffer.disable!
    end

    def merge_buffer_to_meta!
      sniffer_buffer = ::Sniffer.data
      requested_api = sniffer_buffer.size.positive?
      meta["requested_http"] = requested_api
      return unless requested_api
      meta["last_http_session"] = sniffer_buffer.map do |session|
        Hashie.stringify_keys_recursively!(session.to_h)
      end
    end
  end

  module BloodContracts
    module Concerns
      module Snifferable
        def self.included(klass)
          klass.extend ClassMethods
        end

        module ClassMethods
          def sniffer(http_round = nil, meta: nil, **kwargs)
            http_round ||= kwargs[:http_round]
            ContractSniffer.new(http_round: http_round, meta: meta)
          end
        end

        def before_call(meta:, **kwargs)
          super
          @_sniffer = self.class.sniffer(meta: meta)
          @_sniffer.enable!
        end

        def before_runner(*)
          super
          @_sniffer.merge_buffer_to_meta!
          @_sniffer.disable!
          @_sniffer = nil
        end
      end
    end
  end
else
  warn "You're attempted to use Snifferable, but Sniffer class is not "\
       "registered yet. Please, install `sniffer` gem."
end

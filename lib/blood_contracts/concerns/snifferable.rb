if defined?(Sniffer)
  class BloodContracts::Sniffer
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
        Hashie.stringify_keys!(session.to_h)
      end
    end
  end

  module BloodContracts::Concerns::Snifferable
    def sniffer(http_round: nil, meta: nil)
      ContractSniffer.new(http_round: http_round, meta: meta)
    end

    def before_call(meta:, **kwargs)
      super
      @_sniffer = sniffer(meta: meta)
      @_sniffer.enable!
    end

    def after_call(*)
      super
      @_sniffer.merge_buffer_to_meta!
      @_sniffer.disable!
      @_sniffer = nil
    end
  end
end

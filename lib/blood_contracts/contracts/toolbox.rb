module BloodContracts
  module Contracts
    module Toolbox
      using StringPathize

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      def sampler
        return @sampler if defined? @sampler
        s = Sampler.new(contract_name: self.class.to_s.pathize)

        s.input_writer  = method(:input_writer)    if defined? input_writer
        s.input_writer  = method(:request_writer)  if defined? request_writer
        s.output_writer = method(:output_writer)   if defined? output_writer
        s.output_writer = method(:response_writer) if defined? response_writer

        s.input_serializer  = request_serializer if defined? request_serializer
        s.input_serializer  = input_serializer   if defined? input_serializer
        s.output_serializer = output_serializer  if defined? output_serializer
        s.output_serializer = response_serializer if defined? response_serializer

        s.meta_serializer   = meta_serializer if defined? meta_serializer
        @sampler = s.tap(&:init)
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity

      def statistics
        @statistics ||=
          Statistics.new(contract_name: self.class.to_s.pathize).tap(&:init)
      end

      def switcher
        @switcher ||=
          Switcher.new(contract_name: self.class.to_s.pathize).tap(&:init)
      end
    end
  end
end

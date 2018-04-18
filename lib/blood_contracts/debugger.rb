module BloodContracts
  class Debugger < Runner
    option :statistics, default: -> do
      Contracts::Statistics.new(storage, iterations)
    end

    def runs
      @runs ||= debug_runs # storage.find_all_samples(ENV["debug"]).each
    end

    def iterations
      runs.size
    end

    def call(*)
      return Contracts::Round.new unless debugging_samples?

      matcher.call(sampler.load_sample(runs.next)) do |rules|
        Array(rules).each(&statistics.method(:store))
      end
    end

    def description
      return super if debugging_samples?
      "be skipped in current debugging session"
    end

    private

    def debug_runs
      return sampler.find_all_samples(ENV["debug"]).each if ENV["debug"]
      raise "Nothing to debug!" unless File.exist?(config.debug_file)
      found_samples.each
    end

    def found_samples
      @found_samples ||= File.foreach(config.debug_file)
                             .map { |s| s.delete("\n") }
                             .flat_map do |sample|
        sampler.find_all_samples(sample)
      end.compact
    end

    def config
      BloodContracts.config
    end

    def suggestion
      "\n - #{found_samples.join("\n - ")}"
    end

    def debugging_samples?
      runs.size.positive?
    end
  end
end

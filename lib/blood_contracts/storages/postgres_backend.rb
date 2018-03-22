require_relative "./files/name_generator.rb"

module BloodContracts
  module Storages
    class PostgresBackend < BaseBackend
      option :root, default: -> { name }
      alias :contract :example_name
      alias :session :name

      class << self
        def connection
          return @connection if defined? @connection
          raise "'pg' gem was not required" unless defined?(PG)
          @connection = PG.connect(
            BloodContracts.config.storage["database_url"]
          )
        end

        def table_name
          @table_name ||= BloodContracts.config.storage["table_name"]
        end

        def create_table!
          connection.exec(<<-SQL)
            CREATE TABLE IF NOT EXISTS #{table_name} (
              created_at timestamp DEFAULT current_timestamp,

              contract text,
              session text,
              rule text,
              round integer,
              period integer,

              input text,
              output text,
              input_dump text,
              output_dump text,
              meta_dump text,
              error_dump text,
              CONSTRAINT uniq_#{table_name}_name
              UNIQUE(contract, session, period, rule, round)
            );
          SQL
        end
      end

      def_delegators :"self.class", :connection, :table_name
      def_delegators :name_generator,
                     :extract_name_from, :path, :parse, :current_period,
                     :current_round

      def name_generator
        @name_generator ||= Files::NameGenerator.new(name, example_name, "/")
      end

      def suggestion
        "Postgres(#{table_name}):#{path}/*/*"
      end

      def unexpected_suggestion
        "Postgres(#{table_name}):#{path}/#{Storage::UNDEFINED_RULE}/*"
      end

      def find_all_samples(sample_name)
        match = parse(sample_name)
        session, period, rule, round = match.map { |v| v.sub('*', '.*') }
        connection.exec <<-SQL
          SELECT name FROM #{table_name}
          WHERE contract ~ '#{contract}'
          AND session ~ '#{connection.escape_string(session)}'
          AND period ~ '#{period}'
          AND round ~ '#{round}'
          AND rule ~ '#{connection.escape_string(rule)}';
        SQL
      end

      def samples_count(rule)
        connection.exec(<<-SQL).first["count"].to_i
          SELECT COUNT(1) FROM #{table_name}
          WHERE contract = '#{example_name}'
          AND period = '#{current_period}'
          AND rule = '#{connection.escape_string(rule)}';
        SQL
      end

      def sample_exists?(sample_name)
        match = parse(sample_name)
        session, period, rule, round = match.map { |v| v.sub('*', '.*') }
        connection.exec(<<-SQL).first["count"].to_i.positive?
          SELECT COUNT(1) FROM #{table_name}
          WHERE contract ~ '#{contract}'
          AND session ~ '#{connection.escape_string(session)}'
          AND period ~ '#{period}'
          AND round ~ '#{round}'
          AND rule ~ '#{connection.escape_string(rule)}';
        SQL
      end

      def load_sample_chunk(dump_type, sample_name)
        session, period, rule, round = parse(sample_name)
        send("#{dump_type}_serializer")[:load].call(
          connection.exec(<<-SQL).first
            SELECT #{dump_type}_dump FROM #{table_name}
            WHERE contract = '#{contract}'
            AND session = '#{connection.escape_string(session)}'
            AND period = '#{period}'
            AND round = '#{round}'
            AND rule = '#{connection.escape_string(rule)}';
          SQL
        )
      end

      def write(*)
        connection.escape_string(super)
      end

      def describe_sample(rule, round_data, context)
        name_generator.reset_timestamp!
        connection.exec(<<-SQL)
          INSERT INTO #{table_name}
            (contract, session, period, round, rule, input, output)
          VALUES (
            '#{contract}',
            '#{session}',
            '#{current_period}',
            '#{current_round}',
            '#{rule}',
            '#{write(input_writer, context, round_data)}',
            '#{write(output_writer, context, round_data)}'
          )
        SQL
      end

      def serialize_sample_chunk(chunk, rule, round_data, context)
        return unless (dump_proc = send("#{chunk}_serializer")[:dump])
        data = round_data.send(chunk)
        connection.exec(<<-SQL)
          UPDATE #{table_name}
          SET #{chunk}_dump = '#{write(dump_proc, context, data)}'
          WHERE contract = '#{contract}'
          AND session = '#{connection.escape_string(session)}'
          AND period = '#{current_period}'
          AND round = '#{current_round}'
          AND rule = '#{connection.escape_string(rule)}';
        SQL
      end
    end
  end
end

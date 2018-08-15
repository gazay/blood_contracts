require "spec_helper"
require "timecop"

RSpec.describe "Contract Statistics", type: :feature do
  before do
    BloodContracts.config do |config|
      config.enabled = true
      config.statistics["enabled"] = true
    end
  end
  after do
    contract.statistics.delete_all
    contract.sampler.delete_all
    contract.switcher.reset!
    BloodContracts.reset_config!
  end
  let(:weather_service) { WeatherService.new }
  let(:contract) { WeatherUpdateContract.new }

  context "when Redis storage" do
    before do
      BloodContracts.config do |config|
        config.statistics["storage"] = :redis
      end
    end

    context "when all matches are in current period" do
      before do
        5.times do
          weather_service.update(:london)
          weather_service.update(:saint_p)
          weather_service.update(:code_401)
          weather_service.update(:code_404)
        end
        9.times do
          weather_service.update(:parsing_exception) rescue nil
          weather_service.update(:unexpected) rescue nil
        end
        weather_service.update("Errno::ENOENT, please") rescue nil
        contract.call { {} } rescue nil
      end

      it "returns valid statistics" do
        expect(contract.statistics.current)
          .to match(hash_including(
                      "usual" => 10,
                      "usual/london_weather/warm": 5,
                      "usual/saint_p_weather/cold": 5,
                      "error_response/client": 10,
                      parsing_error: 9,
                      __unexpected_behavior__: 9,
                      __unexpected_exception__: 1,
                      __guarantee_failure__: 1
          ))
      end
    end

    context "when matches split between periods" do
      before do
        Timecop.freeze(Time.new(2018, 0o1, 0o1, 13, 0o0))
        5.times do
          weather_service.update(:london)
          weather_service.update(:saint_p)
          weather_service.update(:code_401)
          weather_service.update(:code_404)
        end

        Timecop.freeze(Time.new(2018, 0o1, 0o1, 14, 0o0))
        9.times do
          weather_service.update(:parsing_exception) rescue nil
          weather_service.update(:unexpected) rescue nil
        end
        weather_service.update("Errno::ENOENT, please") rescue nil
        contract.call { {} } rescue nil
      end
      after { Timecop.return }

      let(:previous_period_statistics) do
        contract.statistics.current(Time.new(2018, 0o1, 0o1, 13, 24))
      end

      it "returns valid statistics" do
        expect(contract.statistics.current)
          .to match(hash_including(
                      parsing_error: 9,
                      __unexpected_behavior__: 9,
                      __unexpected_exception__: 1,
                      __guarantee_failure__: 1
          ))
        expect(previous_period_statistics)
          .to match(hash_including(
                      "usual" => 10,
                      "usual/london_weather/warm": 5,
                      "usual/saint_p_weather/cold": 5,
                      "error_response/client": 10,
                      "error_response/empty_rule_name": 10
          ))
        expect(contract.statistics.total.values)
          .to match_array([
                            {
                              parsing_error: 9,
                              __unexpected_behavior__: 9,
                              __unexpected_exception__: 1,
                              __guarantee_failure__: 1
                            },
                            {
                              "usual" => 10,
                              "usual/london_weather/warm": 5,
                              "usual/saint_p_weather/cold": 5,
                              "error_response/client": 10,
                              "error_response/empty_rule_name": 10
                            }
                          ])
      end
    end
  end

  context "when Memory storage" do
    before do
      BloodContracts.config do |config|
        config.statistics["storage"] = :memory
      end
    end

    context "when all matches are in current period" do
      before do
        5.times do
          weather_service.update(:london)
          weather_service.update(:saint_p)
          weather_service.update(:code_401)
          weather_service.update(:code_404)
        end
        9.times do
          weather_service.update(:parsing_exception) rescue nil
          weather_service.update(:unexpected) rescue nil
        end
        weather_service.update("Errno::ENOENT, please") rescue nil
        contract.call { {} } rescue nil
      end

      it "returns valid statistics" do
        expect(contract.statistics.current)
          .to match(hash_including(
                      "usual" => 10,
                      "usual/london_weather/warm": 5,
                      "usual/saint_p_weather/cold": 5,
                      "error_response/client": 10,
                      __unexpected_behavior__: 9,
                      __unexpected_exception__: 1,
                      __guarantee_failure__: 1
          ))
      end
    end

    context "when matches split between periods" do
      before do
        Timecop.freeze(Time.new(2018, 0o1, 0o1, 13, 0o0))
        5.times do
          weather_service.update(:london)
          weather_service.update(:saint_p)
          weather_service.update(:code_401)
          weather_service.update(:code_404)
        end

        Timecop.freeze(Time.new(2018, 0o1, 0o1, 14, 0o0))
        9.times do
          weather_service.update(:parsing_exception) rescue nil
          weather_service.update(:unexpected) rescue nil
        end
        weather_service.update("Errno::ENOENT, please") rescue nil
        contract.call { {} } rescue nil
      end
      after { Timecop.return }

      let(:previous_period_statistics) do
        contract.statistics.current(Time.new(2018, 0o1, 0o1, 13, 24))
      end

      it "returns valid statistics" do
        expect(contract.statistics.current)
          .to match(hash_including(
                      parsing_error: 9,
                      __unexpected_behavior__: 9,
                      __unexpected_exception__: 1,
                      __guarantee_failure__: 1
          ))
        expect(previous_period_statistics)
          .to match(hash_including(
                      "usual" => 10,
                      "usual/london_weather/warm": 5,
                      "usual/saint_p_weather/cold": 5,
                      "error_response/client": 10,
                      "error_response/empty_rule_name": 10
          ))
        expect(contract.statistics.total.values)
          .to match_array([
                            {
                              parsing_error: 9,
                              __unexpected_behavior__: 9,
                              __unexpected_exception__: 1,
                              __guarantee_failure__: 1
                            },
                            {
                              "usual" => 10,
                              "usual/london_weather/warm": 5,
                              "usual/saint_p_weather/cold": 5,
                              "error_response/client": 10,
                              "error_response/empty_rule_name": 10
                            }
                          ])
      end
    end
  end
end

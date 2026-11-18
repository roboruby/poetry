# frozen_string_literal: true

require "json"

# Shared by the AG-UI conformance suites: the vendored data's location, a
# pipeline run that collects what it delivers, raised and warned, and the
# vectors' comparison rules ("$any" matches any present value, "$bind:NAME"
# any string bound consistently, keys a vector marks TS-only are ignored).
module AguiHelper
  ROOT = File.expand_path("fixtures/agui/1.0", __dir__)

  module_function

  # Runs events through a fresh pipeline: { events:, error:, warnings: }.
  def run_pipeline(events, **)
    warnings = []
    delivered = []
    pipeline = Poetry::Agent::AGUI::Pipeline.new(on_warning: ->(warning) { warnings << warning.message }, **)
    events.each { |event| delivered.concat(pipeline.push(event)) }
    delivered.concat(pipeline.finish)
    { events: delivered, error: nil, warnings: warnings, pipeline: pipeline }
  rescue Poetry::Agent::AGUI::ProtocolError => e
    { events: delivered + e.events, error: e, warnings: warnings, pipeline: pipeline }
  end

  # The keys a vector declares TS-only: `tsOnlyKeys`, or a "TS-only keys: a, b" clause in its notes.
  def ignored_keys(vector)
    keys = Array(vector["tsOnlyKeys"]).map(&:to_s)
    clause = vector["notes"].is_a?(String) && vector["notes"][/TS-only keys?:\s*([^.;\n]+)/i, 1]
    keys = clause.split(/[,\s]+/).map { |key| key.delete("`'\"") }.reject(&:empty?) if keys.empty? && clause
    keys
  end

  # A value with the named keys removed at every depth.
  def strip_keys(value, keys)
    return value if keys.empty?

    case value
    when Hash then value.each_with_object({}) { |(k, v), out| out[k] = strip_keys(v, keys) unless keys.include?(k) }
    when Array then value.map { |v| strip_keys(v, keys) }
    else value
    end
  end

  # The corpus's subset match, nil when it holds, else the first difference:
  # arrays the same length, objects on the keys expected names, "$absent"
  # a key that must not be there, "$any" and "$bind:NAME" as in
  # first_difference.
  def subset_difference(expected, actual, path = "", binds = {})
    case expected
    when "$any" then actual.nil? ? "#{path}: missing" : nil
    when Hash
      return "#{path}: expected an object, got #{actual.inspect[0, 160]}" unless actual.is_a?(Hash)

      expected.each do |key, value|
        if value == "$absent"
          return "#{path}.#{key}: should be absent, is #{actual[key].inspect[0, 120]}" if actual.key?(key)
        elsif !actual.key?(key)
          return "#{path}.#{key}: missing (want #{value.inspect[0, 120]})"
        else
          diff = subset_difference(value, actual[key], "#{path}.#{key}", binds)
          return diff if diff
        end
      end
      nil
    when Array
      return "#{path}: expected an array, got #{actual.inspect[0, 160]}" unless actual.is_a?(Array)

      unless expected.size == actual.size
        ids = ->(list) { list.map { |item| item.is_a?(Hash) ? item["id"] : item } }
        return "#{path}: #{actual.size} entries #{ids.call(actual).inspect[0, 200]}, " \
               "want #{expected.size} #{ids.call(expected).inspect[0, 200]}"
      end

      expected.each_with_index do |value, index|
        diff = subset_difference(value, actual[index], "#{path}[#{index}]", binds)
        return diff if diff
      end
      nil
    else first_difference(expected, actual, path, binds)
    end
  end

  # nil when actual matches expected, else the first difference.
  def first_difference(expected, actual, path = "", binds = {})
    return nil if expected == "$any"

    if expected.is_a?(String) && expected.start_with?("$bind:")
      return "#{path}: expected a string, got #{actual.inspect}" unless actual.is_a?(String)

      name = expected.delete_prefix("$bind:")
      binds[name] ||= actual
      return binds[name] == actual ? nil : "#{path}: expected #{binds[name].inspect}, got #{actual.inspect}"
    end

    case expected
    when Hash
      return "#{path}: expected an object, got #{actual.inspect}" unless actual.is_a?(Hash)

      missing = expected.keys - actual.keys
      return "#{path}.#{missing.first}: missing" if missing.any?

      extra = actual.keys - expected.keys
      return "#{path}.#{extra.first}: unexpected" if extra.any?

      expected.each do |key, value|
        diff = first_difference(value, actual[key], "#{path}.#{key}", binds)
        return diff if diff
      end
      nil
    when Array
      return "#{path}: expected an array, got #{actual.inspect}" unless actual.is_a?(Array)
      return "#{path}: expected #{expected.size} entries, got #{actual.size}" unless expected.size == actual.size

      expected.each_with_index do |value, index|
        diff = first_difference(value, actual[index], "#{path}[#{index}]", binds)
        return diff if diff
      end
      nil
    when Numeric then actual.is_a?(Numeric) && actual == expected ? nil : "#{path}: expected #{expected}, got #{actual}"
    else expected == actual ? nil : "#{path}: expected #{expected.inspect}, got #{actual.inspect}"
    end
  end
end

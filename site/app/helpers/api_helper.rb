# frozen_string_literal: true

# View-side massaging of the YARD export for the gallery pages' API
# section: the handler-synthesized boilerplate sentences become table
# columns, leaving the hand-written reference prose as the description.
module ApiHelper
  SECTION_GEMS = { "components" => "poetry-ui", "charts" => "poetry-charts" }.freeze

  BOILERPLATE = [
    /\AConstructor option `[^`]+`\.\z/,
    /\AStyle axis `[^`]+`\.\z/,
    /\ASlot writer for the `[^`]+` slot( \(repeatable\))?\.\z/,
    /\ASlot: the rendered `[^`]+` content\.\z/,
    /\ASlot collection: the rendered `[^`]+` set\.\z/
  ].freeze

  # Lifecycle noise that may linger in exports generated before the
  # @api private sweep - never consumer API.
  NOISE = %w[initialize before_render call].freeze

  def api_component_object(section, slug)
    gem = SECTION_GEMS[section]
    return nil unless gem && ApiReference.slugs.include?(gem)

    class_name = DocsCatalog.class_name_for(section, slug)
    class_name && ApiReference.object(gem, class_name)
  end

  # Style axes first (the visual contract), then options, both as
  # constructor-keyword rows.
  def api_option_rows(object)
    grouped = object["methods"].group_by { |m| m["group"] }
    (grouped["Style axes"] || []) + (grouped["Options"] || [])
  end

  # One row per slot WRITER - the composition verbs a caller uses.
  def api_slot_rows(object)
    (object["methods"].group_by { |m| m["group"] }["Slots"] || [])
      .select { |m| m["name"].start_with?("with_") }
  end

  def api_public_methods(object)
    (object["methods"].group_by { |m| m["group"] }[nil] || [])
      .reject { |m| NOISE.include?(m["name"]) }
  end

  # The hand-written reference prose: the docstring minus the
  # handler-synthesized sentences.
  def api_description(method)
    method["docstring"].to_s.split(/\n{2,}/).map(&:strip)
                       .reject { |para| BOILERPLATE.any? { |re| para.match?(re) } }
                       .join(" ")
  end

  # "defaults to `x`; one of: `a, b`" from the synthesized @return tag.
  def api_details(method)
    method.dig("return", "text").to_s
  end

  def api_types(method)
    Array(method.dig("return", "types")).join(", ")
  end
end

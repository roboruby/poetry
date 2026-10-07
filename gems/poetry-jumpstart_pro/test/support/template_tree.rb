# frozen_string_literal: true

# The installer's template tree: templates/<category>/<view path>.
module TemplateTree
  ROOT = File.expand_path("../../lib/generators/poetry_jumpstart_pro/install/templates", __dir__)

  # Every template as [category, view path relative to app/views].
  def self.each
    return enum_for(:each) unless block_given?

    Dir.glob(File.join(ROOT, "*", "**", "*")).select { |path| File.file?(path) }.sort.each do |path|
      category, relative = path.delete_prefix("#{ROOT}/").split("/", 2)
      yield [category, relative]
    end
  end

  # The view paths of one category.
  def self.views(category)
    each.select { |name, _| name == category }.map(&:last)
  end

  # A template's source.
  def self.read(category, relative)
    File.read(File.join(ROOT, category, relative))
  end

  # Whether a template composes Poetry: a poetry_* helper or the form builder.
  def self.poetry?(source)
    source.match?(/\bpoetry_\w+|Poetry::Ui::FormBuilder/)
  end
end

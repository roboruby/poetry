# frozen_string_literal: true

require "test_helper"

# Generic coverage for EVERY category: installing it writes valid ERB that
# composes poetry components and shadows a view that actually exists in the
# real (private) Jumpstart engine. Auto-covers new categories as they land.
class InstallCategoriesTest < InstallGeneratorTest
  destination File.expand_path("../../tmp/install_categories", __dir__)

  test "every template directory is a known category" do
    assert_equal Poetry::JumpstartPro::CATEGORIES.sort, TemplateTree.each.map(&:first).uniq.sort
  end

  test "no category installs the same view as another" do
    views = TemplateTree.each.map(&:last)

    assert_equal views.uniq.sort, views.sort
  end

  test "with no arguments every category installs" do
    run_generator []

    TemplateTree.each.map(&:last).each { |relative| assert_file "app/views/#{relative}" }
  end

  Poetry::JumpstartPro::CATEGORIES.each do |category|
    define_method("test_#{category}_installs_valid_poetry_views_that_shadow_jumpstart") do
      run_generator [category]
      views = TemplateTree.views(category)

      refute_empty views, "#{category} has no templates"

      uses_poetry = false
      views.each do |relative|
        installed = File.join(destination_root, "app/views", relative)

        assert_path_exists installed, "#{category}: #{relative} was not installed"

        source = File.read(installed)
        ERB.new(source, trim_mode: "-").src # raises on an ERB syntax error
        uses_poetry ||= TemplateTree.poetry?(source)

        assert source.start_with?("<%# Poetry recreation of Jumpstart's"),
               "#{category}: #{relative} should open with the recreation comment"

        next unless JumpstartRepo.path

        original = JumpstartRepo.original_for(relative)

        assert_path_exists original, "#{category}: override #{relative} has no counterpart in Jumpstart (drift?)"
      end

      assert uses_poetry, "#{category} should compose poetry components somewhere"
    end
  end
end

# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "generators/poetry/diff/diff_generator"
require "generators/poetry/add/add_generator"
require "generators/poetry/block/block_generator"

module Poetry
  # poetry:diff - the copy-in drift report. Read-only by contract:
  # every test asserts on the printed report and that nothing was written.
  class DiffGeneratorTest < Rails::Generators::TestCase
    tests Poetry::DiffGenerator
    destination File.expand_path("../tmp/diff-dest", __dir__)
    setup :prepare_destination

    def test_no_manifest_reports_nothing_to_diff
      output = run_generator

      assert_match(/no copy-ins recorded/, output)
    end

    def test_pristine_copy_reports_all_files_match
      add %w[Icon]

      output = run_generator

      assert_match(/same.*icon - copied at #{Regexp.escape(Poetry::Ui::VERSION)}, gem ships/o, output)
      assert_match(/all files match/, output)
    end

    def test_edited_copy_reports_the_differing_file_with_line_counts
      add %w[Icon]
      component = File.join(destination_root, "app/components/poetry/ui/icon/component.rb")
      File.write(component, "#{File.read(component)}\n# local tweak\n")

      output = run_generator

      assert_match(/drift.*icon - copied at/, output)
      assert_match(/component\.rb: differs \(app \d+ lines, gem \d+ lines\)/, output)
    end

    def test_missing_file_points_at_poetry_add
      add %w[Icon]
      FileUtils.rm(File.join(destination_root, "app/components/poetry/ui/icon/preview.rb"))

      output = run_generator

      assert_match(/preview\.rb: not copied locally/, output)
      assert_match(/poetry:add icon/, output)
    end

    def test_local_only_file_is_reported_as_yours
      add %w[Icon]
      File.write(File.join(destination_root, "app/components/poetry/ui/icon/notes.md"), "mine\n")

      output = run_generator

      assert_match(/notes\.md: local-only \(yours\)/, output)
    end

    def test_remote_entries_report_their_source_address
      FileUtils.mkdir_p(File.join(destination_root, "config"))
      File.write(File.join(destination_root, "config/poetry_components.yml"),
                 { "components" => { "fancy-chart" => { "source" => "@acme/fancy-chart" } } }.to_yaml)

      output = run_generator

      assert_match(%r{remote.*fancy-chart - installed from @acme/fancy-chart}, output)
      assert_match(%r{poetry:add @acme/fancy-chart}, output)
    end

    def test_blocks_report_matches_and_edits_with_the_app_owned_caveat
      block "stepper"
      block "top-nav"
      edited = File.join(destination_root, "app/views/blocks/_top_nav.html.erb")
      File.write(edited, File.read(edited).sub("<%", "<!-- edited -->\n<%"))

      output = run_generator

      assert_match(/app-owned starting points/, output)
      assert_match(/same.*stepper - matches the gem's current template/, output)
      assert_match(/edited.*top-nav - differs from the gem's current template/, output)
    end

    def test_diff_never_writes
      add %w[Icon]
      component = File.join(destination_root, "app/components/poetry/ui/icon/component.rb")
      File.write(component, "# gutted\n")
      before = snapshot(destination_root)

      run_generator

      assert_equal before, snapshot(destination_root), "poetry:diff must be read-only"
    end

    private

    def add(names)
      AddGenerator.new(names, [], destination_root: destination_root).invoke_all
    end

    def block(name)
      BlockGenerator.new([name], [], destination_root: destination_root).invoke_all
    end

    def snapshot(root)
      Dir[File.join(root, "**/*")].select { |f| File.file?(f) }.sort.to_h { |f| [f, File.read(f)] }
    end
  end
end

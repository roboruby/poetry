# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/poetry/add/add_generator"
require "generators/poetry/diff/diff_generator"
require "generators/poetry/update/update_generator"

module Poetry
  # poetry:update, and poetry:diff's report of a registry item, over file
  # addresses (no network in the suite): an item is installed, the
  # registry's copy of it changes, and the app's copy is edited or not.
  class UpdateGeneratorTest < Rails::Generators::TestCase
    tests Poetry::UpdateGenerator
    destination File.expand_path("../tmp/update-dest", __dir__)
    setup :prepare_destination

    COMPONENT = "app/components/acme/pricing_table/component.rb"
    STYLE = "app/components/acme/pricing_table/style.rb"
    PREVIEW = "app/components/acme/pricing_table/preview.rb"
    CSS = "app/assets/tailwind/poetry/community/pricing-table.css"
    MANIFEST = "config/poetry_components.yml"

    def item(version, files, css: ".pricing { gap: 1rem; }")
      { "name" => "pricing-table", "type" => "registry:component", "meta" => { "version" => version }, "css" => css,
        "files" => files.map { |path, content| { "path" => path, "content" => content } } }
    end

    def first = item("1", { COMPONENT => "class One\nend\n", STYLE => "class Style\nend\n" })

    def second
      item("2", { COMPONENT => "class Two\nend\n", STYLE => "class Style\nend\n", PREVIEW => "class Preview\nend\n" },
           css: ".pricing { gap: 2rem; }")
    end

    def publish(payload)
      FileUtils.mkdir_p(File.join(destination_root, "items"))
      File.write(File.join(destination_root, "items/pricing-table.json"), JSON.generate(payload))
    end

    # The first version installed from a registry named in the manifest.
    def install
      publish(first)
      FileUtils.mkdir_p(File.join(destination_root, "config"))
      File.write(File.join(destination_root, MANIFEST), YAML.dump("registries" => { "@acme" => "./items/{name}.json" }))
      capture(:stdout) { AddGenerator.new(%w[@acme/pricing-table], [], destination_root: destination_root).invoke_all }
    end

    def edit(target, content) = File.write(File.join(destination_root, target), content)

    def read(target) = File.read(File.join(destination_root, target))

    def record = YAML.safe_load_file(File.join(destination_root, MANIFEST)).dig("components", "pricing-table")

    def digest(content) = Poetry::Core::RegistryInstaller.digest(content)

    def diff(*args)
      capture(:stdout) { DiffGenerator.new([], args, destination_root: destination_root).invoke_all }
    end

    def test_an_unedited_copy_takes_everything_the_registry_changed
      install
      publish(second)

      output = run_generator

      assert_match(/update\s+pricing-table - 1 to 2/, output)
      assert_equal "class Two\nend\n", read(COMPONENT)
      assert_equal "class Preview\nend\n", read(PREVIEW)
      assert_match(/gap: 2rem/, read(CSS))
      assert_equal "2", record["version"]
      assert_equal digest("class Two\nend\n"), record.dig("files", COMPONENT)
      assert_equal [COMPONENT, PREVIEW, STYLE, CSS].sort, record["files"].keys.sort
    end

    def test_an_edited_file_is_kept_and_named_when_the_registry_changed_it_too
      install
      edit(COMPONENT, "class Mine\nend\n")
      publish(second)

      output = run_generator

      assert_match(/kept\s+#{Regexp.escape(COMPONENT)} - edited here, and changed in the registry/o, output)
      assert_equal "class Mine\nend\n", read(COMPONENT)
      assert_equal "class Preview\nend\n", read(PREVIEW), "the rest of the item still updates"
      assert_match(/gap: 2rem/, read(CSS))
      assert_equal "1", record["version"], "the version moves once every file is the registry's"
      assert_equal digest("class One\nend\n"), record.dig("files", COMPONENT),
                   "a kept file keeps the digest it was installed with"
      assert_equal digest("class Preview\nend\n"), record.dig("files", PREVIEW)
    end

    def test_force_replaces_the_edited_file_and_the_record_moves
      install
      edit(COMPONENT, "class Mine\nend\n")
      publish(second)

      run_generator %w[--force]

      assert_equal "class Two\nend\n", read(COMPONENT)
      assert_equal "2", record["version"]
    end

    def test_an_edit_the_registry_did_not_touch_is_kept_without_a_word
      install
      edit(STYLE, "class MyStyle\nend\n")
      publish(second)

      output = run_generator

      refute_match(/kept/, output)
      assert_equal "class MyStyle\nend\n", read(STYLE)
      assert_equal "class Two\nend\n", read(COMPONENT)
    end

    def test_nothing_newer_writes_nothing
      install
      before = read(MANIFEST)

      output = run_generator

      assert_match(/current\s+pricing-table - 1: the registry has nothing newer/, output)
      assert_equal before, read(MANIFEST)
    end

    def test_a_version_that_moved_with_no_file_changed_moves_the_record
      install
      publish(first.merge("meta" => { "version" => "1.1" }))

      output = run_generator

      assert_match(/current\s+pricing-table - 1\.1 \(no file changed since 1\): the registry has nothing newer/, output)
      assert_equal "1.1", record["version"]
      assert_equal "class One\nend\n", read(COMPONENT)
    end

    def test_a_file_the_item_dropped_is_named_and_never_deleted
      install
      publish(item("2", { COMPONENT => "class Two\nend\n" }))

      output = run_generator

      assert_match(/stale\s+#{Regexp.escape(STYLE)} - no longer part of pricing-table/o, output)
      assert_equal "class Style\nend\n", read(STYLE)
    end

    def test_a_name_picks_the_item_and_an_unknown_name_is_an_error
      install
      publish(second)

      run_generator %w[@acme/pricing-table]

      assert_equal "2", record["version"]
      error = assert_raises(ArgumentError) do
        UpdateGenerator.new(%w[absent], [], destination_root: destination_root).invoke_all
      end
      assert_match(/absent is not an item installed from a registry/, error.message)
    end

    def test_an_app_with_no_registry_item_has_nothing_to_update
      assert_match(/no registry items recorded/, run_generator)
    end

    def test_a_registry_that_does_not_answer_is_reported_and_nothing_is_written
      install
      FileUtils.rm(File.join(destination_root, "items/pricing-table.json"))

      output = run_generator

      assert_match(%r{error\s+pricing-table - could not ask @acme/pricing-table}, output)
      assert_equal "class One\nend\n", read(COMPONENT)
    end

    def test_diff_tells_an_edit_here_from_a_change_in_the_registry_and_writes_nothing
      install

      assert_match(%r{same\s+pricing-table - installed from @acme/pricing-table at 1: every file as installed}, diff)
      assert_match(/, and the registry has nothing newer$/, diff)
      edit(STYLE, "class MyStyle\nend\n")

      assert_match(
        /edited\s+pricing-table - .*: the registry has nothing newer\n\s+#{Regexp.escape(STYLE)}: edited here/o, diff
      )
      edit(COMPONENT, "class Mine\nend\n")
      publish(second)
      before = read(MANIFEST)
      output = diff

      assert_match(%r{update\s+pricing-table - .* at 1; the registry has 2: `bin/rails g poetry:update pricing-table`},
                   output)
      assert_match(/#{Regexp.escape(COMPONENT)}: changed in the registry, and edited here/o, output)
      assert_match(/#{Regexp.escape(PREVIEW)}: new in the registry/o, output)
      assert_match(/#{Regexp.escape(CSS)}: changed in the registry$/o, output)
      assert_match(/#{Regexp.escape(STYLE)}: edited here/o, output)
      assert_equal before, read(MANIFEST)
      assert_equal "class Mine\nend\n", read(COMPONENT)
      refute_path_exists File.join(destination_root, PREVIEW)
    end

    def test_diff_reports_a_block_a_registry_item_wrote_with_its_item_and_not_as_a_stray_block
      block = "app/views/blocks/_acme_hero.html.erb"
      publish(item("1", { COMPONENT => "class One\nend\n", block => "<section>Hero</section>\n" }))
      FileUtils.mkdir_p(File.join(destination_root, "config"))
      File.write(File.join(destination_root, MANIFEST), YAML.dump("registries" => { "@acme" => "./items/{name}.json" }))
      capture(:stdout) { AddGenerator.new(%w[@acme/pricing-table], [], destination_root: destination_root).invoke_all }
      File.write(File.join(destination_root, "app/views/blocks/_my_own.html.erb"), "<section>Mine</section>\n")

      output = diff

      assert_match(/same\s+pricing-table/, output)
      refute_match(/yours\s+acme-hero/, output)
      assert_match(/yours\s+my-own - not in the gem catalog/, output)
    end

    def test_diff_offline_reports_the_edits_alone_and_an_unreachable_registry_says_so
      install
      edit(STYLE, "class MyStyle\nend\n")
      publish(second)

      offline = diff("--offline")

      assert_match(/edited\s+pricing-table - .*: the registry was not asked/, offline)
      refute_match(/new in the registry/, offline)
      FileUtils.rm(File.join(destination_root, "items/pricing-table.json"))
      unreachable = diff

      assert_match(%r{remote\s+pricing-table - could not ask @acme/pricing-table}, unreachable)
      assert_match(/#{Regexp.escape(STYLE)}: edited here/o, unreachable)
    end
  end
end

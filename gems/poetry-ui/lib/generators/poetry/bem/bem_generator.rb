# frozen_string_literal: true

require "rails/generators"

module Poetry
  # `rails g poetry:bem` - the css_mode = :bem starter files: the compat
  # stylesheet (the template-static classes poetry-ui's templates carry
  # outside the dictionaries - sr-only, the loading spinner, focus rings,
  # open/closed transitions - compiled once, so the host needs no Tailwind
  # build) and the reference stylesheet (every BEM class every component
  # can emit, as documented selector skeletons for the host's own rules).
  #
  # @example
  #   bin/rails g poetry:bem
  #   # then link both in the layout:
  #   #   stylesheet_link_tag "poetry/bem-compat", "poetry/bem-reference"
  class BemGenerator < Rails::Generators::Base
    # Vendored like tokens: force, never hand-edited, updates flow on re-run.
    COMPAT = "app/assets/stylesheets/poetry/bem-compat.css"
    # App-owned: skip, the host's rules live here.
    REFERENCE = "app/assets/stylesheets/poetry/bem-reference.css"

    # The reference file opens with its ownership rules.

    REFERENCE_HEADER = <<~CSS
      /* poetry BEM reference - written by `rails g poetry:bem`, yours to fill in.
         One block per component, every selector it can emit; each rule's comment
         names the utilities the Tailwind path would resolve. The capsule digest in
         a block's header changes when its dictionary changes on upgrade - re-run
         the generator to a scratch path to read the new reference beside your
         rules; this file itself is never overwritten. */
    CSS

    desc "Write the css_mode = :bem starter files: the compat stylesheet (vendored) and the BEM reference (yours)"

    # Step: the compat stylesheet.
    # @api private
    def copy_compat
      create_file COMPAT, Poetry::Ui.root.join(Poetry::Ui::BEM_COMPAT_PATH).read, force: true
    end

    # Step: the reference stylesheet - Style.descendants is empty until the
    # component classes load (nothing autoloads them under `rails g`).
    # @api private
    def write_reference
      Rails.application.eager_load!
      styles = Poetry::Core::Style.descendants.select(&:name).select(&:bem_block).sort_by(&:bem_block)
      css = styles.map { |style| Poetry::Core::CSS::BemReference.new(style).css }.join("\n\n")
      create_file REFERENCE, "#{REFERENCE_HEADER}\n#{css}\n", skip: true
      say_status :note, "link both in your layout head - stylesheet_link_tag \"poetry/bem-compat\", " \
                        "\"poetry/bem-reference\" - with css_mode = :bem and the BemMerger in " \
                        "config/initializers/poetry.rb", :cyan
    end
  end
end

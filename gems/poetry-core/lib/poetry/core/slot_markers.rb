# frozen_string_literal: true

module Poetry
  module Core
    # What a slot compile writes around a template's own markup, and how to
    # take it off again.
    #
    # A host that compiles its templates with Herb's slots gets every
    # dynamic part of the page marked, so the browser can find it again:
    # comments around a rendering and around each slot, a `data-herb-slot`
    # attribute on an element that carries one, and the branches that did
    # not render, parked in a `<template>` behind the rendering. None of it
    # is the component's. Taken off, what is left is the markup the template
    # wrote, which is what a test or a contract means to compare.
    #
    # @example
    #   html = render_inline(Poetry::Ui::Button::Component.new) { "Save" }.to_html
    #   Poetry::Core::SlotMarkers.strip(html) # => the button, as a plain host renders it
    module SlotMarkers
      # A marker comment: a region, a slot, a branch or the seeds, opening
      # or closing.
      COMMENT = %r{<!--/?herb-[a-z]+\b.*?-->}m

      # The attribute on an element that carries a slot.
      ATTRIBUTE = / data-herb-slot="[^"]*"/

      # Where a parked block opens: branches under `data-herb-region`, the
      # state map under `data-herb-dependencies`.
      PARKED = /<template data-herb-(?:region|dependencies)\b[^>]*>/

      # Either end of a template element.
      TEMPLATE_EDGE = %r{<template\b[^>]*>|</template>}

      class << self
        # The markup without anything a slot compile added. Markup that
        # carries none of it comes back as it went in.
        #
        # @param html [String] rendered markup
        # @return [String] the markup the templates wrote, html-safe when
        #   what it was given was
        def strip(html)
          source = html.to_s
          return html unless source.include?("herb-")

          stripped = without_parked(source).gsub(COMMENT, "").gsub(ATTRIBUTE, "")
          html.respond_to?(:html_safe?) && html.html_safe? ? stripped.html_safe : stripped
        end

        private

        # The markup without its parked blocks. A parked branch may hold a
        # template element of its own, so the end of a block is the closing
        # tag that balances its opening one.
        def without_parked(html)
          kept = +""
          rest = html
          while (opening = rest.match(PARKED))
            kept << opening.pre_match
            rest = after_block(opening.post_match)
          end
          kept << rest
        end

        # What follows the template element whose opening tag was just read.
        def after_block(html)
          depth = 1
          rest = html
          while depth.positive? && (edge = rest.match(TEMPLATE_EDGE))
            depth += edge[0].start_with?("</") ? -1 : 1
            rest = edge.post_match
          end
          depth.zero? ? rest : ""
        end
      end
    end
  end
end

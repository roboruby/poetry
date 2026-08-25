module DocsHelper
  # An example section: title + Preview/Code tabs inside a Card. The
  # preview renders the partial; the code tab shows ITS OWN source (the
  # shadcn model - what you see is exactly what you'd write).
  def docs_example(section, slug, name)
    partial = "examples/#{section}/#{slug}/#{name}"
    source = Rails.root.join("app/views/examples/#{section}/#{slug}/_#{name}.html.erb").read

    render "shared/example",
           partial: partial,
           source: source.strip,
           section: section,
           slug: slug,
           name: name,
           heading: name.tr("_", " ").capitalize,
           note: example_note(section, slug)
  end

  # A muted note shown IN the preview box (not the copied source), for the
  # rare example whose server-side render is intentionally blank. The adapter
  # chart emits a mount + spec for a CLIENT engine (Chart.js, etc.); the docs
  # never load one (server-SVG is the whole pitch), so its mount is empty.
  def example_note(section, slug)
    return unless section == "charts" && slug == "adapter"

    "poetry draws charts as server-side SVG. This adapter is the opt-in path for a client " \
      "engine (Chart.js, etc.) — it emits a themed mount and chart-spec for your registered " \
      "adapter to draw into. These docs don't load a client engine, so the mount is empty here; " \
      "the Code tab shows the mount and spec."
  end

  # Example partial names for a page, in filesystem order with "default"
  # pinned first.
  def docs_examples_for(section, slug)
    dir = Rails.root.join("app/views/examples/#{section}/#{slug}")
    return [] unless dir.exist?

    dir.glob("_*.html.erb")
       .map { |file| file.basename.to_s.delete_prefix("_").delete_suffix(".html.erb") }
       .sort_by { |name| [ name == "default" ? 0 : 1, name ] }
  end

  # The pagination Adapters section's usage snippet lives here because ERB
  # tags can't be embedded in a Ruby string inside a template (the literal
  # %> would close the surrounding scriptlet).
  def pagination_adapter_usage
    <<~ERB.strip
      <%= paginate @products, siblings: 2 %>

      <%= poetry_pagy_nav(@pagy, edges: :icons) %>

      <%= will_paginate @products, renderer: PoetryLinkRenderer,
                        poetry: { current_variant: :filled } %>
    ERB
  end

  # The /pagination guide's per-gem setup snippets (same reason as above:
  # ERB tags can't live in Ruby strings inside a template).
  def pagination_guide_snippets
    {
      install: <<~SHELL.strip,
        bundle add kaminari                      # or: pagy / will_paginate
        bin/rails g poetry:pagination            # detects every loaded paginator
        bin/rails g poetry:pagination kaminari   # or name one: kaminari | pagy | will_paginate
      SHELL
      kaminari: <<~RUBY.strip,
        # controller - kaminari's own API, unchanged
        @products = Product.page(params[:page]).per(10)

        # view - your existing call; poetry options ride along
        <%= paginate @products, siblings: 2 %>
      RUBY
      pagy: <<~RUBY.strip,
        # controller - include Pagy::Method (ApplicationController), then
        @pagy, @products = pagy(:offset, Product.all, limit: 10)

        # view - the adapter's helper
        <%= poetry_pagy_nav(@pagy) %>
      RUBY
      will_paginate: <<~RUBY.strip
        # controller - will_paginate's own API, unchanged
        @products = Product.paginate(page: params[:page], per_page: 10)

        # view - pass the adapter renderer; poetry options under poetry:
        <%= will_paginate @products, renderer: PoetryLinkRenderer,
                          poetry: { edges: :icons } %>
      RUBY
    }
  end

  # The /optimistic-forms guide's snippets (same reason as above: ERB tags
  # can't live in Ruby strings inside a template).
  def optimistic_forms_guide_snippets
    {
      usage: <<~ERB.strip,
        <%# A favorite toggle: the template predicts the TOGGLED state,
            the button shows the current one. %>
        <%= poetry_optimistic_form(model: photo, attribute_name: :favorite, value: !photo.favorite) do |form| %>
          <%= form.optimistic_template dom_id(photo, "favorite-icon"), favorite_icon(!photo.favorite) %>
          <%= poetry_button(type: :submit) { favorite_icon(photo.favorite) } %>
        <% end %>

        <%# A submit that updates a region elsewhere on the page. %>
        <%= poetry_optimistic_form(url: cart_items_path, method: :post, attribute_name: :photo_id, value: photo.id) do |form| %>
          <%= form.optimistic_template "cart-count", (@cart_count + 1) %>
          <%= poetry_button(type: :submit) { "Add to cart" } %>
        <% end %>
      ERB
      server: <<~RUBY.strip,
        def update
          @photo = Photo.find(params[:id])

          if @photo.update(photo_params)
            head :no_content
          else
            flash[:alert] = "Your change could not be saved."
            head :unprocessable_entity
          end
        end
      RUBY
      correction_partial: <<~ERB.strip,
        <%# app/views/photos/_favorite_icon.html.erb - the single source of truth %>
        <span id="<%= dom_id(photo, "favorite-icon") %>"><%= favorite_icon(photo.favorite) %></span>

        <%# the prediction: the same partial, opposite state %>
        <%= form.optimistic_template do %>
          <%= turbo_stream.update dom_id(photo, "favorite-icon") do %>
            <%= favorite_icon(!photo.favorite) %>
          <% end %>
        <% end %>
      ERB
      correction_server: <<~RUBY.strip,
        # the authoritative success response
        render turbo_stream: turbo_stream.update(
          ActionView::RecordIdentifier.dom_id(@photo, "favorite-icon"),
          partial: "photos/favorite_icon", locals: { photo: @photo }
        )
      RUBY
      streams: <<~ERB.strip
        <%= form.optimistic_template do %>
          <%= turbo_stream.update("cart-count") { @cart_count + 1 } %>
          <%= turbo_stream.remove(dom_id(photo, "add-button")) %>
        <% end %>
      ERB
    }
  end

  # The /theming guide's ERB snippets (same reason as above).
  def theming_guide_snippets
    {
      color_scheme_head: <<~ERB.strip,
        <head>
          <%= poetry_color_scheme_script %>
          <%# ...stylesheet and javascript tags... %>
        </head>
      ERB
      color_scheme_toggle: <<~ERB.strip,
        <%= poetry_button(variant: :ghost, size: :icon, label: "Toggle dark mode",
                          onclick: "Poetry.colorScheme.toggle()") do %>
          <%= poetry_icon(name: :"sun-moon") %>
        <% end %>
      ERB
      portal_container: <<~ERB.strip
        <div class="my-scoped-theme">
          <div id="scoped-overlays"></div>
          <%= poetry_popover("data-poetry-portal-container": "scoped-overlays") do |popover| %>
            <% popover.with_trigger(variant: :outline) { "Open" } %>
            <% popover.with_title { "Stays in the scope" } %>
          <% end %>
        </div>
      ERB
    }
  end

# The user's explicit sidebar disclosure choices (written by the
# sidebar-sections Stimulus controller as a name => open map). An
# explicit choice overrides the current-section default when the
# sidebar re-renders on the next visit.
def sidebar_section_states
  value = JSON.parse(cookies[:docs_sidebar].to_s)
  value.is_a?(Hash) ? value : {}
rescue JSON::ParserError
  {}
end

  # Example/block source panels ride the CodeBlock component: the
  # theme-owned syntax palette replaces the vendored GitHub rouge.css, and
  # every code tab gains the copy affordance.
  def highlight_erb(source)
    poetry_code_block(code: source, language: "erb", label: "Example source", line_numbers: true)
  end
end

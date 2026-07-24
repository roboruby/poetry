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

  # Example/block source panels ride the CodeBlock component: the
  # theme-owned syntax palette replaces the vendored GitHub rouge.css, and
  # every code tab gains the copy affordance.
  def highlight_erb(source)
    poetry_code_block(code: source, language: "erb", label: "Example source", line_numbers: true)
  end
end

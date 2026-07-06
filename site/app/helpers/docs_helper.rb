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
           heading: name.tr("_", " ").capitalize
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

  def highlight_erb(source)
    formatter = Rouge::Formatters::HTML.new
    lexer = Rouge::Lexers::ERB.new
    content_tag(:div, formatter.format(lexer.lex(source)).html_safe,
                class: "highlight overflow-x-auto rounded-md border bg-muted/30 p-4 text-sm leading-relaxed")
  end
end

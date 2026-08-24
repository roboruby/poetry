# frozen_string_literal: true

# Renders YARD docstrings (markdown-flavored prose) as HTML for the /api
# pages. Deliberately tiny: the docstrings use a narrow subset - paragraphs,
# `code` spans, **bold**, "- " lists, fenced code blocks - and everything is
# escaped first, so no markdown gem and no raw HTML pass-through.
module ApiMarkdown
  module_function

  def render(text)
    return "".html_safe if text.blank?

    blocks = []
    fence = nil
    list = nil
    para = nil

    flush = lambda do
      blocks << "<ul class=\"list-disc pl-5 flex flex-col gap-1\">#{list.join}</ul>" if list
      blocks << "<p>#{inline(para.join(' '))}</p>" if para
      list = nil
      para = nil
    end

    text.each_line do |raw|
      line = raw.rstrip
      if fence
        if line.strip.start_with?("```")
          blocks << "<pre class=\"rounded-md border bg-muted/50 p-3 font-mono text-xs overflow-x-auto\"><code>#{ERB::Util.html_escape(fence.join("\n"))}</code></pre>"
          fence = nil
        else
          fence << line
        end
      elsif line.strip.start_with?("```")
        flush.call
        fence = []
      elsif line.strip.start_with?("- ")
        blocks << "<p>#{inline(para.join(' '))}</p>" if para
        para = nil
        (list ||= []) << "<li>#{inline(line.strip.delete_prefix('- '))}</li>"
      elsif line.strip.empty?
        flush.call
      else
        blocks << "<ul class=\"list-disc pl-5 flex flex-col gap-1\">#{list.join}</ul>" if list
        list = nil
        (para ||= []) << line.strip
      end
    end
    blocks << "<pre class=\"rounded-md border bg-muted/50 p-3 font-mono text-xs overflow-x-auto\"><code>#{ERB::Util.html_escape(fence.join("\n"))}</code></pre>" if fence
    flush.call

    blocks.join("\n").html_safe
  end

  # Escaped text -> code spans + bold. Order matters: escape first, then
  # substitute on the escaped string.
  def inline(text)
    out = ERB::Util.html_escape(text).to_s
    out = out.gsub(/`([^`]+)`/) { "<code class=\"font-mono text-[0.8em] text-foreground\">#{Regexp.last_match(1)}</code>" }
    out.gsub(/\*\*([^*]+)\*\*/) { "<strong>#{Regexp.last_match(1)}</strong>" }
  end
end

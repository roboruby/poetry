# frozen_string_literal: true

module Poetry
  module Ui
    module Typeset
      # The Typeset preview: a rendered-markdown fixture (the element soup a
      # markdown renderer emits - headings, prose, list, quote, code, table)
      # styled entirely by the app-owned typeset.css.
      class Preview < Poetry::Core::Preview::Base
        FIXTURE = <<~HTML
          <h1>The Pilcrow Papers</h1>
          <p>You render markdown and get back plain, unstyled HTML - headings,
          paragraphs, lists, tables. <strong>Typeset</strong> styles everything
          inside the container from three rhythm variables, and
          <a href="#rhythm">everything else derives</a>.</p>
          <h2 id="rhythm">Rhythm</h2>
          <p>Three controls: <code>--typeset-size</code>,
          <code>--typeset-leading</code>, and <code>--typeset-flow</code>.</p>
          <ul>
            <li>It fits its container - chat bubble or article.</li>
            <li>It reads your theme tokens, so dark mode is free.</li>
            <li>Appending a block never restyles earlier blocks.</li>
          </ul>
          <blockquote><p>Utilities on an element still win - the rules are
          zero-specificity.</p></blockquote>
          <pre><code>gem "poetry-ui"</code></pre>
          <table>
            <thead><tr><th>Control</th><th>Default</th></tr></thead>
            <tbody>
              <tr><td>size</td><td>1em</td></tr>
              <tr><td>leading</td><td>1.75</td></tr>
              <tr><td>flow</td><td>1.25em</td></tr>
            </tbody>
          </table>
        HTML

        def default
          render_component(class: "max-w-xl") do
            FIXTURE.html_safe
          end
        end
      end
    end
  end
end

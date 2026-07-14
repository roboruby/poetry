# frozen_string_literal: true

module Poetry
  module Ui
    module Tree
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(label: "Files") do |tree|
            tree.with_item(text: "docs", value: "docs", expanded: true) do |docs|
              docs.with_item(text: "guides", value: "guides") do |guides|
                guides.with_item(text: "intro.md", value: "intro")
                guides.with_item(text: "advanced.md", value: "advanced")
              end
              docs.with_item(text: "README.md", value: "docs-readme")
            end
            tree.with_item(text: "src", value: "src") do |src|
              src.with_item(text: "main.rb", value: "main")
            end
            tree.with_item(text: "LICENSE", value: "license")
          end
        end

        # Server-persisted expansion: collapsed parents render their
        # subtree hidden; nested collapsed state survives cycles.
        def deeply_nested
          render_component(label: "Organization") do |tree|
            tree.with_item(text: "Engineering", value: "eng", expanded: true) do |eng|
              eng.with_item(text: "Platform", value: "platform", expanded: true) do |platform|
                platform.with_item(text: "Infra", value: "infra") do |infra|
                  infra.with_item(text: "On-call", value: "oncall")
                end
              end
              eng.with_item(text: "Product", value: "product", disabled: true)
            end
            tree.with_item(text: "Design", value: "design")
          end
        end

        # href: items render their labels as links (a file navigator).
        def with_links
          render_component(label: "Pages") do |tree|
            tree.with_item(text: "Getting started", value: "start", expanded: true) do |start|
              start.with_item(text: "Install", value: "install", href: "#install")
              start.with_item(text: "Theming", value: "theming", href: "#theming")
            end
          end
        end

        def empty
          render_component(label: "Files")
        end
      end
    end
  end
end

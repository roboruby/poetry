# frozen_string_literal: true

module Poetry
  module Core
    module X
      class Style < Poetry::Core::Style
        class_variants(
          base: "shrink-0",
          variants: {
            mode: {
              light: "",
              dark: ""
            },
            color: {
              red: "stroke-red-600/50 group-hover:stroke-red-600/75",
              orange: "stroke-orange-600/50 group-hover:stroke-orange-600/75",
              amber: "stroke-amber-600/50 group-hover:stroke-amber-600/75",
              yellow: "stroke-yellow-600/50 group-hover:stroke-yellow-600/75",
              lime: "stroke-lime-600/50 group-hover:stroke-lime-600/75",
              green: "stroke-green-600/50 group-hover:stroke-green-600/75",
              emerald: "stroke-emerald-600/50 group-hover:stroke-emerald-600/75",
              teal: "stroke-teal-600/50 group-hover:stroke-teal-600/75",
              cyan: "stroke-cyan-600/50 group-hover:stroke-cyan-600/75",
              sky: "stroke-sky-600/50 group-hover:stroke-sky-600/75",
              blue: "stroke-blue-600/50 group-hover:stroke-blue-600/75",
              indigo: "stroke-indigo-600/50 group-hover:stroke-indigo-600/75",
              violet: "stroke-violet-600/50 group-hover:stroke-violet-600/75",
              purple: "stroke-purple-600/50 group-hover:stroke-purple-600/75",
              fuchsia: "stroke-fuchsia-600/50 group-hover:stroke-fuchsia-600/75",
              pink: "stroke-pink-600/50 group-hover:stroke-pink-600/75",
              rose: "stroke-rose-600/50 group-hover:stroke-rose-600/75",
              slate: "stroke-slate-600/50 group-hover:stroke-slate-600/75",
              gray: "stroke-gray-600/50 group-hover:stroke-gray-600/75",
              zinc: "stroke-zinc-600/50 group-hover:stroke-zinc-600/75",
              neutral: "stroke-neutral-600/50 group-hover:stroke-neutral-600/75",
              stone: "stroke-stone-600/50 group-hover:stroke-stone-600/75"
            },
            size: {
              small: "size-3",
              medium: "size-3.5",
              large: "size-4"
            },
            shape: {
              square: "",
              round: ""
            }
          },
          compound_variants: [
            # Dark mode colors
            { color: :red, mode: :dark, class: "stroke-red-400 group-hover:stroke-red-300" },
            { color: :orange, mode: :dark, class: "stroke-orange-400 group-hover:stroke-orange-300" },
            { color: :amber, mode: :dark, class: "stroke-amber-400 group-hover:stroke-amber-300" },
            { color: :yellow, mode: :dark, class: "stroke-yellow-400 group-hover:stroke-yellow-300" },
            { color: :lime, mode: :dark, class: "stroke-lime-400 group-hover:stroke-lime-300" },
            { color: :green, mode: :dark, class: "stroke-green-400 group-hover:stroke-green-300" },
            { color: :emerald, mode: :dark, class: "stroke-emerald-400 group-hover:stroke-emerald-300" },
            { color: :teal, mode: :dark, class: "stroke-teal-400 group-hover:stroke-teal-300" },
            { color: :cyan, mode: :dark, class: "stroke-cyan-400 group-hover:stroke-cyan-300" },
            { color: :sky, mode: :dark, class: "stroke-sky-400 group-hover:stroke-sky-300" },
            { color: :blue, mode: :dark, class: "stroke-blue-400 group-hover:stroke-blue-300" },
            { color: :indigo, mode: :dark, class: "stroke-indigo-400 group-hover:stroke-indigo-300" },
            { color: :violet, mode: :dark, class: "stroke-violet-400 group-hover:stroke-violet-300" },
            { color: :purple, mode: :dark, class: "stroke-purple-400 group-hover:stroke-purple-300" },
            { color: :fuchsia, mode: :dark, class: "stroke-fuchsia-400 group-hover:stroke-fuchsia-300" },
            { color: :pink, mode: :dark, class: "stroke-pink-400 group-hover:stroke-pink-300" },
            { color: :rose, mode: :dark, class: "stroke-rose-400 group-hover:stroke-rose-300" },
            { color: :slate, mode: :dark, class: "stroke-slate-400 group-hover:stroke-slate-300" },
            { color: :gray, mode: :dark, class: "stroke-gray-400 group-hover:stroke-gray-300" },
            { color: :zinc, mode: :dark, class: "stroke-zinc-400 group-hover:stroke-zinc-300" },
            { color: :neutral, mode: :dark, class: "stroke-neutral-400 group-hover:stroke-neutral-300" },
            { color: :stone, mode: :dark, class: "stroke-stone-400 group-hover:stroke-stone-300" }
          ],
          defaults: {
            mode: :light,
            color: :indigo,
            size: :medium,
            shape: :square
          }
        )
      end
    end
  end
end

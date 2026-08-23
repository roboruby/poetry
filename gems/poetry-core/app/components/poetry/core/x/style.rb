# frozen_string_literal: true

module Poetry
  module Core
    module X
      class Style < Poetry::Core::Style
        base "shrink-0"

        variant :mode, light: "", dark: ""

        variant :color, {
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
        }

        variant :size, {
          small: "size-3",
          medium: "size-3.5",
          large: "size-4"
        }

        variant :shape, {
          square: "",
          round: ""
        }

        # Dark-mode stroke colors (compound: color x mode). NOTE: this
        # hand-written color x mode fan-out is exactly what the semantic-role
        # token contract eliminates for real poetry-ui components -
        # X is retained legacy reference code, not the pattern to copy.
        {
          red: "stroke-red-400 group-hover:stroke-red-300",
          orange: "stroke-orange-400 group-hover:stroke-orange-300",
          amber: "stroke-amber-400 group-hover:stroke-amber-300",
          yellow: "stroke-yellow-400 group-hover:stroke-yellow-300",
          lime: "stroke-lime-400 group-hover:stroke-lime-300",
          green: "stroke-green-400 group-hover:stroke-green-300",
          emerald: "stroke-emerald-400 group-hover:stroke-emerald-300",
          teal: "stroke-teal-400 group-hover:stroke-teal-300",
          cyan: "stroke-cyan-400 group-hover:stroke-cyan-300",
          sky: "stroke-sky-400 group-hover:stroke-sky-300",
          blue: "stroke-blue-400 group-hover:stroke-blue-300",
          indigo: "stroke-indigo-400 group-hover:stroke-indigo-300",
          violet: "stroke-violet-400 group-hover:stroke-violet-300",
          purple: "stroke-purple-400 group-hover:stroke-purple-300",
          fuchsia: "stroke-fuchsia-400 group-hover:stroke-fuchsia-300",
          pink: "stroke-pink-400 group-hover:stroke-pink-300",
          rose: "stroke-rose-400 group-hover:stroke-rose-300",
          slate: "stroke-slate-400 group-hover:stroke-slate-300",
          gray: "stroke-gray-400 group-hover:stroke-gray-300",
          zinc: "stroke-zinc-400 group-hover:stroke-zinc-300",
          neutral: "stroke-neutral-400 group-hover:stroke-neutral-300",
          stone: "stroke-stone-400 group-hover:stroke-stone-300"
        }.each do |color, classes|
          compound({ color: color, mode: :dark }, classes)
        end
      end
    end
  end
end

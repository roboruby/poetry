# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The vocabulary-drift gate (N6 W2 regression class): every data-*
    # attribute a Style dictionary STYLES must be an attribute something
    # actually EMITS - the JS state layer (config/state_vocabulary.json,
    # introspected from helpers/state.js), or a documented non-state
    # attribute below. The accordion chevron bug was exactly this drift:
    # a [&[data-state=open]>svg] selector whose attribute lost its writer
    # when the state layer migrated - it styled nothing, silently.
    class StateVocabularyTest < ActiveSupport::TestCase
      STATE_MANIFEST = Poetry::Core.root.join("config/state_vocabulary.json")

      # Non-state attributes dictionaries legitimately style. Each entry
      # names its emitter - if you add one, say where it comes from.
      NON_STATE_ATTRIBUTES = {
        "slot" => "data-slot self-identification (every part, server-rendered)",
        "side" => "popper placement reflection (popper controller)",
        "align" => "popper placement reflection (popper controller)",
        "orientation" => "server-rendered layout axis (roving/slider/toggle-group/separator)",
        # The bridge orientation VARIANTS (data-horizontal:/data-vertical:) -
        # not attributes; they match [data-orientation=horizontal|vertical].
        "horizontal" => "bridge variant for data-orientation=horizontal (shadcn/tailwind.css)",
        "vertical" => "bridge variant for data-orientation=vertical (shadcn/tailwind.css)",
        "highlighted" => "menu/command/select active-option marker (JS)",
        "copied" => "clipboard-text post-copy beat (poetry--core--clipboard-text via " \
                    "toggleAttribute; drives the copy/check glyph swap)",
        "disabled" => "server-rendered + JS-reflected disabled marker",
        "placeholder" => "select trigger empty-value marker (server + JS)",
        "active" => "OTP caret cell / tab markers (JS)",
        "variant" => "server-rendered style variant marker",
        "inset" => "menu item inset marker (server-rendered)",
        "enhanced" => "date/time field progressive-enhancement marker " \
                      "(poetry--core--date-field via setAttribute)",
        "selected" => "table row selection marker (poetry--core--table-selection via " \
                      "toggleAttribute; aria-selected is the canonical twin)",
        "expanded" => "tree row open marker (server-rendered + poetry--core--tree via " \
                      "toggleAttribute; aria-expanded is the canonical twin)",
        "invalid" => "server-rendered invalid marker on segment-field groups ",
        "today" => "calendar today-cell marker (server + poetry--core--calendar via setAttribute, N9 W6)",
        "outside" => "calendar outside-month day marker (server + poetry--core--calendar, N9 W6)",
        "range-start" => "calendar range-start day (v2 range mode; server/controller, N9 W6)",
        "range-middle" => "calendar range-middle day (v2 range mode, N9 W6)",
        "range-end" => "calendar range-end day (v2 range mode, N9 W6)",
        "state" => "sidebar expanded/collapsed marker (poetry--core--sidebar reflects it via " \
                   "setAttribute; the CSS collapse hook, N9 W5)",
        "collapsible" => "sidebar collapse-mode marker (server + poetry--core--sidebar; " \
                         "the mode while collapsed, N9 W5)",
        "viewport" => "navigation-menu mode marker (server-rendered; false = per-item popups, N9 W4c)",
        "sidebar" => "sidebar part marker (server-rendered; menu-action reserves menu-button room " \
                     "via group-has, W5b c3)",
        "activation-direction" => "navigation-menu travel direction (poetry--core--navigation-menu " \
                                  "stamps it on both panels during viewport switches, D3)",
        "icon" => "trigger icon-position marker (consumer-stamped on tab icons; static markup, N9 W2)",
        "size" => "server-rendered size marker",
        "spacing" => "server-rendered spacing marker",
        "position" => "toaster stack position (server-rendered)",
        "direction" => "message/scroller direction marker (server-rendered)",
        "autoscrolling" => "message-scroller follow state (JS)",
        "upload-state" => "attachment lifecycle (server-owned, W2 resolution)",
        "mode" => "message-scroller scroll mode (JS, W1 resolution)",
        "instant" => "tooltip instant-open reason (JS, W1 resolution)",
        "queued" => "toast overflow queue marker (JS)",
        "dragging" => "slider drag marker (JS)",
        "complete" => "OTP complete marker (JS)",
        "completed" => "timeline progress marker (server-rendered)",
        "swiping" => "drawer swipe drag marker (poetry--core--drawer writes it; toast swipe reserved)",
        "snap-points" => "drawer snap-points marker (server-rendered when snap_points: is present; " \
                         "drives the dictionary's full-height sizing, 2026-08-01)",
        "starting-style" => "presence enter hook (presence.js enterPresence - one painted frame, " \
                            "the Base UI transition idiom; Drawer is the first consumer)",
        "ending-style" => "presence exit hook (presence.js exitPresence - rides the whole exit)",
        "swipe-direction" => "toast swipe (reserved)",
        "type" => "questionnaire choice input kind (server-rendered: radio | checkbox)",
        "shortcut" => "questionnaire choice key label (server-rendered; the controller matches " \
                      "keystrokes against it)"
      }.freeze

      EXTRACTORS = [
        /(?:group-|peer-)?data-\[([a-z-]+)[\]=^~]/, # data-[x], data-[x=v], group-data-[x^=v]
        /(?:group-|peer-)?data-([a-z-]+):/,         # bridge/native variants data-x:
        /\[data-([a-z-]+)[\]=]/                     # arbitrary selectors [&[data-x=v]>svg]
      ].freeze

      def test_every_styled_data_attribute_has_an_emitter
        emitted = JSON.parse(STATE_MANIFEST.read).fetch("attributes")
                      .map { |attribute| attribute.delete_prefix("data-") }
        allowed = (emitted + NON_STATE_ATTRIBUTES.keys).to_set

        offenses = []
        Dir[Poetry::Ui::Engine.root.join("app/components/**/style.rb")].each do |file|
          source = File.read(file)
          EXTRACTORS.each do |extractor|
            source.scan(extractor) do |(name)|
              offenses << "#{file}: data-#{name}" unless allowed.include?(name)
            end
          end
        end

        assert_empty offenses,
                     "dictionaries style data-* attributes nothing emits (the dead-hook bug class) - " \
                     "either wire an emitter, or document the attribute in NON_STATE_ATTRIBUTES:\n" \
                     "#{offenses.uniq.join("\n")}"
      end

      def test_the_state_manifest_is_present_and_sane
        vocabulary = JSON.parse(STATE_MANIFEST.read)

        assert_includes vocabulary.fetch("attributes"), "data-open"
        assert_includes vocabulary.fetch("keys"), "popup-open"
        refute_includes vocabulary.fetch("attributes"), "data-state",
                        "the legacy attribute must never re-enter the vocabulary"
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class SlotMarkersTest < Minitest::Test
      PLAIN = %(<button class="a" data-slot="button"><span data-slot="label">Save</span></button>)

      def test_markup_without_markers_comes_back_as_it_went_in
        assert_same PLAIN, SlotMarkers.strip(PLAIN)
      end

      def test_region_and_slot_comments_come_off
        marked = [
          %(<!--herb-region:app/components/x.html.erb:c33869ba:0--><!--herb-slot:0:block-->),
          %(<button class="a" data-slot="button"><span data-slot="label">),
          %(<!--herb-slot:1-->Save<!--/herb-slot:1--></span></button>),
          %(<!--/herb-slot:0--><!--/herb-region:app/components/x.html.erb-->)
        ].join

        assert_equal PLAIN, SlotMarkers.strip(marked)
      end

      def test_the_slot_attribute_comes_off_and_the_others_stay
        marked = %(<input type="hidden" name="terms" value="0" data-herb-slot="5:attribute:name 6:attribute:value">)

        assert_equal %(<input type="hidden" name="terms" value="0">), SlotMarkers.strip(marked)
      end

      def test_a_parked_branch_comes_off_with_everything_in_it
        marked = [
          %(<div data-slot="drawer"></div><!--/herb-region:x-->),
          %(<template data-herb-region="x:9e8187d9"><!--herb-branch:2:0-->),
          %(<div data-slot="drawer-swipe-handle"></div></template>)
        ].join

        assert_equal %(<div data-slot="drawer"></div>), SlotMarkers.strip(marked)
      end

      # A parked branch may hold a template element of its own: the block
      # ends at the closing tag that balances its opening one.
      def test_a_parked_branch_holding_a_template_comes_off_whole
        marked = [
          %(<p>kept</p><template data-herb-region="x:1"><div><template data-target="error">),
          %(<p>inner</p></template></div></template><p>after</p>)
        ].join

        assert_equal %(<p>kept</p><p>after</p>), SlotMarkers.strip(marked)
      end

      def test_a_template_the_component_wrote_stays
        html = %(<turbo-frame><template data-target="error"><p>Failed</p></template></turbo-frame>)
        marked = %(<!--herb-region:x:1:0-->#{html}<!--/herb-region:x-->)

        assert_equal html, SlotMarkers.strip(marked)
      end

      def test_the_state_map_comes_off
        marked = %(<p>kept</p><template data-herb-dependencies>{"state":{}}</template>)

        assert_equal %(<p>kept</p>), SlotMarkers.strip(marked)
      end

      def test_safe_markup_stays_safe
        marked = %(<!--herb-slot:0-->x<!--/herb-slot:0-->).html_safe

        assert_predicate SlotMarkers.strip(marked), :html_safe?
        refute_predicate SlotMarkers.strip(%(<!--herb-slot:0-->x<!--/herb-slot:0-->)), :html_safe?
      end
    end
  end
end

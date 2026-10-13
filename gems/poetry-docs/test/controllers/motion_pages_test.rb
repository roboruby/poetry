# frozen_string_literal: true

require "test_helper"

# The Motion section: one page per poetry-motion effect, the library guide,
# and the two API pages.
class MotionPagesTest < ActionDispatch::IntegrationTest
  test "every effect page renders its install step, examples and behaviors" do
    Poetry::Docs::DocsCatalog.motion.each do |entry|
      get entry.path

      assert_response :success, entry.path
      assert_select "h1", entry.title
      assert_select "#installation", 1
      assert_includes response.body, "poetry-motion", entry.path
      assert_select "[data-slot=#{entry.slug}]", minimum: 1
    end

    get "/motion/tilt-card"

    assert_select "#behaviors"
  end

  test "the effects are in the sidebar and the library guide lists the ten behaviors" do
    get "/libraries/motion"

    assert_response :success
    assert_select "a[href='/motion/marquee']"
    %w[useAnimate useSpring useStagger useScrollValue usePointer useFrame useLayout useDrag useGesture
       useCanvas].each { |name| assert_includes response.body, name }
    assert_select "#this-is-css"
  end

  test "the API reference documents the motion gem's Ruby and JavaScript" do
    get "/api/poetry-motion"

    assert_response :success
    assert_includes response.body, "Poetry::Motion::Options"

    get "/api/poetry-motion-controllers"

    assert_response :success
    assert_includes response.body, "poetry--motion--number-ticker"
  end
end

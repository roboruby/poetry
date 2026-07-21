require "test_helper"

class SystemMailerTest < ActionMailer::TestCase
  test "ping renders both parts and delivers" do
    email = SystemMailer.ping(note: "hello from the test suite")

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "ops@example.com" ], email.to
    assert_equal "[poetry-docs] ping", email.subject
    assert_includes email.html_part.body.to_s, "hello from the test suite"
    assert_includes email.text_part.body.to_s, "hello from the test suite"
  end
end

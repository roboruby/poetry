require "test_helper"

class ActiveStorageTest < ActiveSupport::TestCase
  test "blob upload and download roundtrip through the disk service" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("poetry-docs storage smoke"),
      filename: "smoke.txt",
      content_type: "text/plain"
    )

    assert blob.persisted?
    assert blob.service.exist?(blob.key)
    assert_equal "poetry-docs storage smoke", blob.download
    assert_equal "text/plain", blob.content_type
  ensure
    blob&.purge
  end
end

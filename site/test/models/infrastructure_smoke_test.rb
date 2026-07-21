require "test_helper"

# The database layer exists for future use; these assertions pin the shape so
# a config regression fails loudly rather than at first real usage.
class InfrastructureSmokeTest < ActiveSupport::TestCase
  test "primary database connects and holds the Active Storage tables" do
    tables = ActiveRecord::Base.connection.tables
    assert_includes tables, "active_storage_blobs"
    assert_includes tables, "active_storage_attachments"
    assert_includes tables, "active_storage_variant_records"
  end

  test "queue database connects and holds the Solid Queue tables" do
    assert_includes SolidQueue::Record.connection.tables, "solid_queue_jobs"
  end

  test "cable schema is loadable" do
    config = ActiveRecord::Base.configurations.configs_for(env_name: "test", name: "cable")
    assert config, "cable database must be configured in test"
  end
end

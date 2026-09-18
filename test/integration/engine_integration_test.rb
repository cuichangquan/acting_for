require "test_helper"
require "open3"
require "rbconfig"

class EngineIntegrationTest < ActiveSupport::TestCase
  test "acting for engine inherits from Rails engine" do
    assert_operator ActingFor::Engine, :<, Rails::Engine
  end

  test "dummy application is initialized with acting for engine loaded" do
    assert_predicate Rails.application, :initialized?
    assert Rails.application.railties.any? { |railtie| railtie.is_a?(ActingFor::Engine) }
  end

  test "acting for engine isolates its namespace" do
    assert_predicate ActingFor::Engine, :isolated?
    assert_equal "acting_for_", ActingFor.table_name_prefix
  end

  test "host and engine agent constants coexist without namespace collisions" do
    assert_equal "Agent", ::Agent.name
    assert_equal "ActingFor::Agent", ActingFor::Agent.name
    refute_same ::Agent, ActingFor::Agent
    assert_equal "Agent", ::Agent.model_name.name
    assert_equal "ActingFor::Agent", ActingFor::Agent.model_name.name
  end

  %w[Agent Delegation AuditEvent].each do |name|
    test "dummy resolves acting for #{name} as an ActiveRecord model" do
      model = "ActingFor::#{name}".constantize
      assert_operator model, :<, ActingFor::ApplicationRecord
      assert_operator model, :<, ActiveRecord::Base
    end
  end

  %w[Decision Error InvalidRequestError InternalError AuditPersistenceError].each do |name|
    test "dummy resolves public acting for #{name} constant" do
      assert_instance_of Class, "ActingFor::#{name}".constantize
    end
  end

  test "a fresh dummy application boots and eager loads host and engine components" do
    script = <<~RUBY
      Rails.application.eager_load!
      abort "Dummy did not initialize" unless Rails.application.initialized?
      abort "Engine not loaded" unless Rails.application.railties.any? { |r| r.is_a?(ActingFor::Engine) }
      %w[Agent Delegation AuditEvent Decision Error InvalidRequestError InternalError AuditPersistenceError].each do |name|
        abort "Missing constant" unless "ActingFor::\#{name}".constantize.is_a?(Class)
      end
      abort "Namespace collision" if ::Agent == ActingFor::Agent
      abort "Missing host principal" unless Principal < ActiveRecord::Base
    RUBY
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, "-r", Rails.root.join("config/environment").to_s, "-e", script
    )
    assert status.success?, "Fresh boot/eager load failed:\n#{stdout}\n#{stderr}"
  end

  {
    "Agent" => "acting_for_agents",
    "Delegation" => "acting_for_delegations",
    "AuditEvent" => "acting_for_audit_events"
  }.each do |name, table|
    test "dummy database contains the #{table} table" do
      assert ActiveRecord::Base.connection.data_source_exists?(table)
    end

    test "acting for #{name} connects to #{table}" do
      model = "ActingFor::#{name}".constantize
      assert_equal table, model.table_name
      assert_predicate model, :table_exists?
      assert_kind_of Integer, model.count
    end
  end

  test "test migration checks use the dummy host migration directory" do
    expected = [Rails.root.join("db/migrate").to_s]
    assert_equal expected, Rails.application.paths["db/migrate"].to_a
    assert_equal expected, ActiveRecord::Migrator.migrations_paths
    assert_equal expected, ActiveRecord::Tasks::DatabaseTasks.migrations_paths
  end

  test "dummy host migrations are applied separately from gem source migrations" do
    context = ActiveRecord::Base.connection_pool.migration_context
    host_migrations = context.migrations
    assert host_migrations.any?
    assert host_migrations.all? { |migration| Pathname.new(migration.filename).dirname == Rails.root.join("db/migrate") }
    assert_equal [], context.open.pending_migrations

    gem_root = ActingFor::Engine.root
    refute_equal Rails.root, gem_root
    source_context = ActiveRecord::MigrationContext.new(gem_root.join("db/migrate").to_s)
    source_migrations = source_context.migrations
    assert_equal %w[CreateActingForAgents CreateActingForAuditEvents CreateActingForDelegations], source_migrations.map(&:name).sort
    source_migrations.each do |source|
      host = host_migrations.find { |migration| migration.name == source.name }
      refute_nil host
      refute_equal source.filename, host.filename
    end
  end

  test "engine agent records can be created and retrieved through ActiveRecord" do
    agent = ActingFor::Agent.create!(identifier: "engine-integration-agent")
    assert_predicate agent, :persisted?
    assert_equal "engine-integration-agent", ActingFor::Agent.find(agent.id).identifier
  end

  test "engine delegation associates with its agent and the host principal" do
    agent = ActingFor::Agent.create!(identifier: "engine-association-agent")
    principal = Principal.create!
    delegation = ActingFor.delegate(agent: agent, principal: principal, action: :purchase, effect: :allow)
    stored = ActingFor::Delegation.find(delegation.id)

    assert_equal agent, stored.agent
    assert_equal principal, stored.principal
    assert_includes agent.delegations, stored
  end

  test "engine authorization persists an audit record readable through ActiveRecord" do
    agent = ActingFor::Agent.create!(identifier: "engine-audit-agent")
    principal = Principal.create!
    delegation = ActingFor.delegate(agent: agent, principal: principal, action: :purchase, effect: :allow)

    assert_difference "ActingFor::AuditEvent.count", 1 do
      assert_equal :allow, ActingFor.authorize(agent: agent, principal: principal, action: :purchase).status
    end
    event = ActingFor::AuditEvent.sole
    assert_equal event, ActingFor::AuditEvent.find(event.id)
    assert_equal agent.id, event.agent_id
    assert_equal [delegation.id], event.matched_delegation_ids
  end
end

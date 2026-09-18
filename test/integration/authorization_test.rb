require "test_helper"
require "bigdecimal"

class AuthorizationTest < ActiveSupport::TestCase
  class Resource
    extend ActiveModel::Naming

    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  class OtherResource < Resource
  end

  class ResourceWithoutId
    extend ActiveModel::Naming
  end

  setup do
    travel_to Time.utc(2026, 9, 18, 12)
    @agent = ActingFor::Agent.create!(identifier: "authorization-test-agent")
    @principal = Principal.create!
    @resource = Resource.new(123)
  end

  test "authorize returns allow for a matching allow delegation" do
    delegate
    decision = authorize
    assert_equal :allow, decision.status
    assert_predicate decision, :allowed?
  end

  test "authorize returns deny when no delegation matches" do
    decision = authorize
    assert_equal :deny, decision.status
    assert_predicate decision, :denied?
  end

  test "authorize returns require approval without permission to execute automatically" do
    delegate(effect: :require_approval)
    decision = authorize
    assert_equal :require_approval, decision.status
    assert_predicate decision, :approval_required?
    refute_predicate decision, :allowed?
  end

  %i[allow require_approval].each do |first_effect|
    %i[allow require_approval].each do |specific_effect|
      %i[earlier later].each do |first_timestamp|
        test "authorize prioritizes approval with #{first_effect} created first and " \
             "#{specific_effect} specific and first timestamp #{first_timestamp}" do
          second_effect = first_effect == :allow ? :require_approval : :allow
          delegations = [first_effect, second_effect].map do |effect|
            delegate(effect: effect, resource: effect == specific_effect ? @resource : Resource)
          end
          first, second = delegations
          first.update_columns(created_at: Time.current + (first_timestamp == :earlier ? -60 : 60))
          second.update_columns(created_at: Time.current)

          assert_equal :require_approval, authorize.status
          assert_equal delegations.map(&:id).sort, audit.matched_delegation_ids
        end
      end
    end
  end

  {
    "different agent" => -> { { agent: ActingFor::Agent.create!(identifier: "other-agent") } },
    "different principal" => -> { { principal: Principal.create! } },
    "different principal type" => -> { { principal: @agent } },
    "different action" => -> { { action: "refund" } },
    "different resource type" => -> { { resource: OtherResource.new(123) } },
    "different specific resource id" => -> { { resource: Resource.new(456) } }
  }.each do |name, attributes|
    test "authorize excludes a delegation with #{name}" do
      delegate(**instance_exec(&attributes))
      assert_equal :deny, authorize.status
      assert_equal [], audit.matched_delegation_ids
    end
  end

  test "authorize accepts a type wide delegation for a specific resource" do
    delegation = delegate(resource: Resource)
    assert_equal :allow, authorize.status
    assert_equal [delegation.id], audit.matched_delegation_ids
  end

  test "authorize accepts a type wide delegation for a resource class request" do
    delegate(resource: Resource)
    assert_equal :allow, authorize(resource: Resource).status
    assert_equal Resource.model_name.name, audit.resource_type
    assert_nil audit.resource_id
  end

  test "authorize excludes a specific delegation from a resource class request" do
    delegate
    assert_equal :deny, authorize(resource: Resource).status
  end

  test "authorize matches a resource less delegation only to a resource less request" do
    delegate(resource: nil)
    assert_equal :allow, authorize(resource: nil).status
    assert_nil audit.resource_type
    assert_nil audit.resource_id
  end

  test "authorize does not treat a resource less delegation as a wildcard" do
    delegate(resource: nil)
    assert_equal :deny, authorize.status
  end

  test "authorize excludes a typed delegation from a resource less request" do
    delegate(resource: Resource)
    assert_equal :deny, authorize(resource: nil).status
  end

  test "authorize compares normalized resource ids without numeric coercion" do
    delegate(resource: Resource.new("0123"))
    assert_equal :deny, authorize(resource: Resource.new(123)).status
  end

  test "authorize accepts a delegation with no expiration" do
    delegate(expires_at: nil)
    assert_equal :allow, authorize.status
  end

  test "authorize accepts a delegation before its expiration" do
    delegate(expires_at: Time.current + 60)
    assert_equal :allow, authorize.status
  end

  test "authorize excludes a delegation exactly at its expiration" do
    expiration = Time.current + 60
    delegate(expires_at: expiration)
    travel_to expiration
    assert_equal :deny, authorize.status
    assert_equal [], audit.matched_delegation_ids
  end

  test "authorize excludes a delegation after its expiration" do
    expiration = Time.current + 60
    delegate(expires_at: expiration)
    travel_to expiration + 1
    assert_equal :deny, authorize.status
  end

  test "authorize excludes a revoked delegation" do
    delegate.revoke!
    assert_equal :deny, authorize.status
    assert_equal [], audit.matched_delegation_ids
  end

  {
    "passing constraint" => [{ amount: 100 }, :allow],
    "failing constraint" => [{ amount: 101 }, :deny],
    "missing context field" => [{}, :deny],
    "nil context field" => [{ amount: nil }, :deny],
    "numeric string type mismatch" => [{ amount: "100" }, :deny],
    "float type mismatch" => [{ amount: 100.0 }, :deny],
    "string context key" => [{ "amount" => 100 }, :deny]
  }.each do |name, (context, expected)|
    test "authorize handles #{name} without implicit conversion" do
      delegate(constraints: [{ field: :amount, operator: :lte, value: 100 }])
      assert_equal expected, authorize(context: context).status
    end
  end

  test "authorize requires every constraint to pass" do
    delegate(constraints: [
               { field: :amount, operator: :lte, value: 100 },
               { field: :currency, operator: :eq, value: "JPY" }
             ])
    assert_equal :deny, authorize(context: { amount: 100, currency: "USD" }).status
  end

  test "authorize does not interpret nested context paths" do
    delegate(constraints: [{ field: "order.amount", operator: :eq, value: 100 }])
    assert_equal :deny, authorize(context: { order: { amount: 100 } }).status
  end

  test "authorize matches an exact top level symbol containing a dot" do
    delegate(constraints: [{ field: "order.amount", operator: :eq, value: 100 }])
    assert_equal :allow, authorize(context: { "order.amount": 100 }).status
  end

  {
    "non array constraints" => {},
    "non hash entry" => [1],
    "unknown operator" => [{ "field" => "amount", "operator" => "unknown", "value" => 100 }],
    "extra key" => [{ "field" => "amount", "operator" => "eq", "value" => 100, "extra" => true }],
    "invalid comparison value" => [{ "field" => "amount", "operator" => "lte", "value" => "100" }]
  }.each do |name, constraints|
    test "authorize fails closed for persisted #{name}" do
      delegation = delegate
      # Simulate malformed stored data without changing the public creation contract.
      delegation.update_columns(constraints: constraints)
      assert_equal :deny, authorize(context: { amount: 100 }).status
      assert_equal [], audit.matched_delegation_ids
    end
  end

  test "authorize still permits a valid match alongside an invalid approval constraint" do
    valid = delegate
    invalid = delegate(effect: :require_approval)
    invalid.update_columns(constraints: [{ "field" => "amount", "operator" => "unknown", "value" => 100 }])
    assert_equal :allow, authorize(context: { amount: 100 }).status
    assert_equal [valid.id], audit.matched_delegation_ids
  end

  test "authorize ignores mismatching approval when another delegation matches" do
    valid = delegate
    delegate(effect: :require_approval, action: "refund")
    assert_equal :allow, authorize.status
    assert_equal [valid.id], audit.matched_delegation_ids
  end

  test "authorize accepts persisted agent and principal" do
    delegate
    assert_equal :allow, authorize(agent: @agent, principal: @principal).status
  end

  test "authorize accepts a string action" do
    delegate
    assert_equal :allow, authorize(action: "purchase").status
    assert_equal "purchase", audit.action
  end

  test "authorize normalizes a symbol action to string" do
    delegate
    assert_equal :allow, authorize(action: :purchase).status
    assert_equal "purchase", audit.action
  end

  test "authorize preserves surrounding whitespace in nonblank action" do
    delegate(action: " purchase ")
    assert_equal :allow, authorize(action: " purchase ").status
    assert_equal " purchase ", audit.action
  end

  test "authorize does not downcase actions" do
    delegate
    assert_equal :deny, authorize(action: "PURCHASE").status
    assert_equal "PURCHASE", audit.action
  end

  test "authorize accepts a Hash context" do
    delegate
    assert_equal :allow, authorize(context: { amount: 100 }).status
  end

  test "authorize normalizes a non ActiveRecord resource instance for the audit" do
    delegate
    authorize(resource: Resource.new(123))
    assert_equal Resource.model_name.name, audit.resource_type
    assert_equal "123", audit.resource_id
  end

  {
    "nil agent" => -> { { agent: nil } },
    "wrong class agent" => -> { { agent: @principal } },
    "unsaved agent" => -> { { agent: ActingFor::Agent.new(identifier: "unsaved") } },
    "nil principal" => -> { { principal: nil } },
    "non ActiveRecord principal" => -> { { principal: Struct.new(:id).new(1) } },
    "unsaved principal" => -> { { principal: Principal.new } },
    "nil action" => -> { { action: nil } },
    "empty action" => -> { { action: "" } },
    "whitespace action" => -> { { action: "   " } },
    "integer action" => -> { { action: 1 } },
    "resource class without model name" => -> { { resource: Object } },
    "resource instance without id" => -> { { resource: ResourceWithoutId.new } },
    "resource with nil id" => -> { { resource: Resource.new(nil) } },
    "resource with empty id" => -> { { resource: Resource.new("") } },
    "string resource identifier" => -> { { resource: "Resource:123" } },
    "hash resource identifier" => -> { { resource: { id: 123 } } },
    "nil context" => -> { { context: nil } },
    "array context" => -> { { context: [] } },
    "string context" => -> { { context: "amount=100" } }
  }.each do |name, attributes|
    test "authorize raises invalid request for #{name} rather than returning deny" do
      assert_invalid(**instance_exec(&attributes))
    end
  end

  { allow: "delegation_allowed", deny: "no_matching_delegation",
    require_approval: "delegation_requires_approval" }.each do |status, reason|
    test "authorize automatically persists one audit for #{status}" do
      delegate(effect: status) unless status == :deny
      assert_difference "ActingFor::AuditEvent.count", 1 do
        assert_equal status, authorize.status
      end
      assert_equal status.to_s, audit.decision
      assert_equal reason, audit.reason_code
    end
  end

  {
    agent_id: -> { @agent.id },
    agent_identifier: -> { @agent.identifier },
    principal_type: -> { "Principal" },
    principal_id: -> { @principal.id.to_s },
    action: -> { "purchase" },
    resource_type: -> { Resource.model_name.name },
    resource_id: -> { "123" },
    created_at: -> { Time.current }
  }.each do |attribute, expected|
    test "authorize persists the #{attribute} snapshot" do
      authorize
      assert_equal instance_exec(&expected), audit.public_send(attribute)
    end
  end

  test "authorize preserves the agent identifier snapshot after the agent changes" do
    authorize
    @agent.update!(identifier: "changed-agent")
    assert_equal "authorization-test-agent", audit.agent_identifier
  end

  test "authorize records no matched ids for deny" do
    authorize
    assert_equal [], audit.matched_delegation_ids
  end

  test "authorize records every matching id in ascending canonical order" do
    matches = [delegate(effect: :require_approval, resource: Resource), delegate, delegate]
    delegate(action: "refund")
    delegate(resource: Resource.new(456))
    delegate.revoke!
    assert_equal :require_approval, authorize.status
    assert_equal matches.map(&:id).sort, audit.matched_delegation_ids
  end

  test "authorize records all allow matches even when they have identical contents" do
    matches = [delegate, delegate]
    assert_equal :allow, authorize.status
    assert_equal matches.map(&:id).sort, audit.matched_delegation_ids
  end

  { "nil" => nil, "single symbol" => :amount, "string element" => ["amount"],
    "mixed string and symbol elements" => [:amount, "currency"], "hash" => {} }.each do |name, keys|
    test "authorize rejects #{name} audit context keys" do
      assert_invalid(audit_context_keys: keys)
    end
  end

  %i[password password_confirmation token access_token refresh_token api_key secret client_secret
     credential].each do |key|
    test "authorize rejects forbidden #{key} even when absent from context" do
      assert_invalid(audit_context_keys: [key])
    end
  end

  test "authorize deduplicates audit context keys" do
    authorize(context: { amount: 100 }, audit_context_keys: %i[amount amount])
    assert_equal({ "amount" => 100 }, audit.sanitized_context)
  end

  test "authorize ignores missing audit context keys" do
    authorize(context: { amount: 100 }, audit_context_keys: %i[amount missing])
    assert_equal({ "amount" => 100 }, audit.sanitized_context)
  end

  test "authorize selects exact symbol keys and persists canonical string keys" do
    authorize(context: { amount: 100, "amount" => 200 }, audit_context_keys: [:amount])
    assert_equal({ "amount" => 100 }, audit.sanitized_context)
  end

  test "authorize does not select string context keys through indifferent access" do
    authorize(context: { "amount" => 100 }, audit_context_keys: [:amount])
    assert_equal({}, audit.sanitized_context)
  end

  test "authorize does not select a HashWithIndifferentAccess string key" do
    authorize(context: { amount: 100 }.with_indifferent_access, audit_context_keys: [:amount])
    assert_equal({}, audit.sanitized_context)
  end

  test "authorize does not interpret audit context keys as nested paths" do
    authorize(context: { order: { amount: 100 } }, audit_context_keys: [:"order.amount"])
    assert_equal({}, audit.sanitized_context)
  end

  test "authorize selects a literal top level audit key containing a dot" do
    authorize(context: { "order.amount": 100 }, audit_context_keys: [:"order.amount"])
    assert_equal({ "order.amount" => 100 }, audit.sanitized_context)
  end

  test "authorize never falls back to raw context without an allowlist" do
    authorize(context: { amount: 100, password: "private", nested: { value: 1 } })
    assert_equal({}, audit.sanitized_context)
  end

  test "authorize never falls back to raw context when no selected key exists" do
    authorize(context: { amount: 100 }, audit_context_keys: [:missing])
    assert_equal({}, audit.sanitized_context)
  end

  test "authorize ignores unselected unsupported context values" do
    authorize(context: { amount: 100, nested: Object.new }, audit_context_keys: [:amount])
    assert_equal({ "amount" => 100 }, audit.sanitized_context)
  end

  test "authorize uses exact forbidden key names without substring matching" do
    authorize(context: { token_count: 3 }, audit_context_keys: [:token_count])
    assert_equal({ "token_count" => 3 }, audit.sanitized_context)
  end

  { "string" => "JPY", "integer" => 100, "float" => 1.5,
    "true" => true, "false" => false, "nil" => nil }.each do |name, value|
    test "authorize persists selected #{name} audit value without conversion" do
      authorize(context: { value: value }, audit_context_keys: [:value])
      assert_equal({ "value" => value }, audit.sanitized_context)
    end
  end

  { "hash" => {}, "array" => [1], "symbol" => :amount,
    "object" => Object.new }.each do |name, value|
    test "authorize rejects a selected unsupported #{name} audit value" do
      assert_invalid(context: { value: value }, audit_context_keys: [:value])
    end
  end

  test "authorize preserves BigDecimal precision in a decimal string" do
    decimal = BigDecimal("12345678901234567890.1234567890123456789")
    authorize(context: { amount: decimal }, audit_context_keys: [:amount])
    assert_equal({ "amount" => "12345678901234567890.1234567890123456789" }, audit.sanitized_context)
  end

  test "authorize does not mutate caller context" do
    context = { amount: BigDecimal("123.456"), nested: { values: [1, 2] }, "amount" => 999 }
    original = context.deep_dup
    authorize(context: context, audit_context_keys: [:amount])
    assert_equal original, context
    refute_predicate context, :frozen?
  end

  test "authorize does not mutate caller audit context keys" do
    keys = %i[amount amount missing]
    authorize(context: { amount: 100 }, audit_context_keys: keys)
    assert_equal %i[amount amount missing], keys
    refute_predicate keys, :frozen?
  end

  %i[allow deny require_approval].each do |status|
    test "authorize raises audit persistence error instead of returning #{status} on save failure" do
      delegate(effect: status) unless status == :deny
      original = ActiveRecord::StatementInvalid.new("simulated persistence failure")
      calls = 0
      with_audit_create(lambda { |*|
        calls += 1
        raise original
      }) do
        assert_no_difference "ActingFor::AuditEvent.count" do
          error = assert_raises(ActingFor::AuditPersistenceError) { authorize }
          assert_same original, error.cause
        end
      end
      assert_equal 1, calls
    end
  end

  test "authorize wraps a real audit model validation failure and preserves its cause" do
    validation = ->(record) { record.errors.add(:base, "host test validation failure") }
    ActingFor::AuditEvent.validate(validation)
    begin
      assert_no_difference "ActingFor::AuditEvent.count" do
        error = assert_raises(ActingFor::AuditPersistenceError) { authorize }
        assert_instance_of ActiveRecord::RecordInvalid, error.cause
      end
    ensure
      ActingFor::AuditEvent.skip_callback(:validate, :before, validation)
    end
  end

  test "authorize propagates unexpected non ActiveRecord persistence errors" do
    original = TypeError.new("unexpected persistence error")
    with_audit_create(->(*) { raise original }) do
      assert_same original, assert_raises(TypeError) { authorize }
    end
  end

  test "authorize does not wrap unexpected audit snapshot errors" do
    original = ArgumentError.new("unexpected snapshot error")
    @agent.define_singleton_method(:identifier) { raise original }
    assert_no_difference "ActingFor::AuditEvent.count" do
      assert_same original, assert_raises(ArgumentError) { authorize }
    end
  end

  test "authorize does not wrap ActiveRecord errors outside audit persistence" do
    original = ActiveRecord::ActiveRecordError.new("unexpected principal identity error")
    @principal.define_singleton_method(:id) { raise original }
    assert_no_difference "ActingFor::AuditEvent.count" do
      assert_same original, assert_raises(ActiveRecord::ActiveRecordError) { authorize }
    end
  end

  test "authorize propagates delegation lookup system failure instead of deny" do
    original = ActiveRecord::StatementInvalid.new("simulated delegation lookup failure")
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      raise original if payload[:sql].match?(/\bFROM\s+"acting_for_delegations"/i)
    end
    assert_no_difference "ActingFor::AuditEvent.count" do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_same original, assert_raises(ActiveRecord::StatementInvalid) { authorize }
      end
    end
  end

  private

  def authorize(**overrides)
    ActingFor.authorize(agent: @agent, principal: @principal, action: "purchase",
                        resource: @resource, **overrides)
  end

  def delegate(**overrides)
    ActingFor.delegate(agent: @agent, principal: @principal, action: "purchase", resource: @resource,
                       effect: :allow, **overrides)
  end

  def audit
    ActingFor::AuditEvent.sole
  end

  def assert_invalid(**overrides)
    assert_no_difference "ActingFor::AuditEvent.count" do
      assert_raises(ActingFor::InvalidRequestError) { authorize(**overrides) }
    end
  end

  def with_audit_create(replacement)
    klass = ActingFor::AuditEvent
    singleton = klass.singleton_class
    owned = singleton.method_defined?(:create!, false)
    original = klass.method(:create!)
    singleton.define_method(:create!, replacement)
    yield
  ensure
    if owned
      singleton.define_method(:create!, original)
    else
      singleton.remove_method(:create!)
    end
  end
end

require "test_helper"

class DelegationTest < ActiveSupport::TestCase
  class SpecializedAgent < ActingFor::Agent
  end

  class Resource
    extend ActiveModel::Naming

    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  class ResourceWithoutId
    extend ActiveModel::Naming
  end

  class ResourceWithoutModelName
    attr_reader :id

    def initialize
      @id = 1
    end
  end

  setup do
    travel_to Time.utc(2026, 9, 18, 12)
    @agent = ActingFor::Agent.create!(identifier: "delegation-test-agent")
    @principal = Principal.create!
  end

  test "delegate accepts a persisted agent" do
    assert_equal @agent, delegate.reload.agent
  end

  test "delegate accepts a persisted subclass of agent" do
    agent = SpecializedAgent.create!(identifier: "specialized-agent")
    assert_equal agent.id, delegate(agent: agent).reload.agent_id
  end

  {
    "nil agent" => -> {},
    "wrong class agent" => -> { @principal },
    "unsaved agent" => -> { ActingFor::Agent.new(identifier: "unsaved") }
  }.each do |name, input|
    test "delegate rejects #{name}" do
      assert_invalid(agent: instance_exec(&input))
    end
  end

  test "delegate accepts a persisted principal through polymorphic association" do
    delegation = delegate.reload
    assert_equal @principal, delegation.principal
    assert_equal "Principal", delegation.principal_type
    assert_equal @principal.id.to_s, delegation.principal_id
  end

  {
    "nil principal" => -> {},
    "string principal" => -> { "1" },
    "hash principal" => -> { { id: 1 } },
    "plain object principal with an id" => -> { Struct.new(:id).new(1) },
    "unsaved principal" => -> { Principal.new }
  }.each do |name, input|
    test "delegate rejects #{name}" do
      assert_invalid(principal: instance_exec(&input))
    end
  end

  test "delegate preserves string action" do
    assert_equal "purchase", delegate(action: "purchase").reload.action
  end

  test "delegate converts symbol action to string" do
    assert_equal "purchase", delegate(action: :purchase).reload.action
  end

  test "delegate preserves surrounding whitespace in nonblank action" do
    assert_equal " purchase ", delegate(action: " purchase ").reload.action
  end

  { "nil" => nil, "empty string" => "", "whitespace" => "   ",
    "integer" => 1, "object" => Object.new }.each do |name, input|
    test "delegate rejects #{name} action" do
      assert_invalid(action: input)
    end
  end

  test "delegate stores nil resource as an unrestricted scope" do
    delegation = delegate(resource: nil).reload
    assert_nil delegation.resource_type
    assert_nil delegation.resource_id
  end

  test "delegate accepts an ActiveModel style resource class" do
    delegation = delegate(resource: Resource).reload
    assert_equal Resource.model_name.name, delegation.resource_type
    assert_nil delegation.resource_id
  end

  test "delegate accepts a non ActiveRecord resource instance without persistence methods" do
    delegation = delegate(resource: Resource.new(123)).reload
    assert_equal Resource.model_name.name, delegation.resource_type
    assert_equal "123", delegation.resource_id
  end

  test "delegate accepts an ActiveRecord resource instance" do
    delegation = delegate(resource: @principal).reload
    assert_equal Principal.model_name.name, delegation.resource_type
    assert_equal @principal.id.to_s, delegation.resource_id
  end

  {
    "resource class without model name" => -> { Object },
    "resource instance without model name" => -> { ResourceWithoutModelName.new },
    "resource instance without id" => -> { ResourceWithoutId.new },
    "resource instance with nil id" => -> { Resource.new(nil) },
    "resource instance with empty string id" => -> { Resource.new("") },
    "resource instance whose id converts to empty string" => -> { Resource.new(Class.new { def to_s = "" }.new) },
    "string resource identifier" => -> { "Product:123" },
    "hash resource identifier" => -> { { type: "Product", id: 123 } }
  }.each do |name, input|
    test "delegate rejects #{name}" do
      assert_invalid(resource: instance_exec(&input))
    end
  end

  { "string allow" => "allow", "symbol allow" => :allow,
    "string require approval" => "require_approval",
    "symbol require approval" => :require_approval }.each do |name, input|
    test "delegate accepts #{name} effect" do
      assert_equal input.to_s, delegate(effect: input).reload.effect
    end
  end

  { "nil" => nil, "string deny" => "deny", "symbol deny" => :deny,
    "uppercase" => "ALLOW", "surrounding whitespace" => " allow ",
    "hyphenated alias" => "require-approval", "unknown" => "unknown",
    "integer" => 1 }.each do |name, input|
    test "delegate rejects #{name} effect" do
      assert_invalid(effect: input)
    end
  end

  test "delegate defaults constraints to an empty array" do
    assert_equal [], delegate.reload.constraints
  end

  test "delegate accepts explicit empty constraints" do
    assert_equal [], delegate(constraints: []).reload.constraints
  end

  test "delegate canonicalizes symbol constraint keys field and operator" do
    constraints = [{ field: :amount, operator: :lte, value: 10_000 }]
    assert_equal [{ "field" => "amount", "operator" => "lte", "value" => 10_000 }],
                 delegate(constraints: constraints).reload.constraints
  end

  test "delegate accepts mixed string and symbol constraint keys" do
    constraints = [{ "field" => "amount", operator: "eq", "value" => 100 }]
    assert_equal [{ "field" => "amount", "operator" => "eq", "value" => 100 }],
                 delegate(constraints: constraints).reload.constraints
  end

  {
    "nil container" => nil,
    "hash container" => {},
    "non hash entry" => [1],
    "missing key" => [{ field: "amount", operator: "eq" }],
    "extra key" => [{ field: "amount", operator: "eq", value: 1, extra: true }],
    "non string or symbol key" => [{ 1 => "amount", operator: "eq", value: 1 }],
    "duplicate normalized key" => [{ field: "amount", "field" => "price", operator: "eq", value: 1 }],
    "empty field" => [{ field: "", operator: "eq", value: 1 }],
    "invalid field type" => [{ field: 1, operator: "eq", value: 1 }],
    "invalid operator type" => [{ field: "amount", operator: 1, value: 1 }],
    "unknown operator" => [{ field: "amount", operator: "between", value: 1 }],
    "uppercase operator" => [{ field: "amount", operator: "EQ", value: 1 }],
    "whitespace operator" => [{ field: "amount", operator: " eq ", value: 1 }]
  }.each do |name, input|
    test "delegate rejects constraints with #{name}" do
      assert_invalid(constraints: input)
    end
  end

  { "string" => "100", "integer" => 100, "true" => true, "false" => false }.each do |name, value|
    test "delegate accepts #{name} eq constraint value without conversion" do
      assert_equal value, delegate(constraints: [constraint("eq", value)]).reload.constraints.first["value"]
    end
  end

  { "nil" => nil, "symbol" => :amount, "float" => 1.5,
    "array" => [1], "hash" => {} }.each do |name, value|
    test "delegate rejects #{name} eq constraint value" do
      assert_invalid(constraints: [constraint("eq", value)])
    end
  end

  %w[lt lte gt gte].each do |operator|
    test "delegate accepts integer #{operator} constraint value" do
      assert_equal 100, delegate(constraints: [constraint(operator, 100)]).reload.constraints.first["value"]
    end

    { "numeric string" => "100", "float" => 100.0, "boolean" => true }.each do |name, value|
      test "delegate rejects #{name} #{operator} constraint value" do
        assert_invalid(constraints: [constraint(operator, value)])
      end
    end
  end

  test "delegate accepts mixed scalar types in an in constraint" do
    values = ["100", 100, true, false]
    assert_equal values, delegate(constraints: [constraint("in", values)]).reload.constraints.first["value"]
  end

  test "delegate accepts an empty in constraint array" do
    assert_equal [], delegate(constraints: [constraint("in", [])]).reload.constraints.first["value"]
  end

  test "delegate preserves order and duplicates in an in constraint array" do
    values = [2, 1, 1]
    assert_equal values, delegate(constraints: [constraint("in", values)]).reload.constraints.first["value"]
  end

  test "delegate rejects a non array in constraint value" do
    assert_invalid(constraints: [constraint("in", 1)])
  end

  { "nil" => nil, "symbol" => :amount, "float" => 1.5,
    "nested array" => [1], "hash" => {} }.each do |name, value|
    test "delegate rejects #{name} element in an in constraint" do
      assert_invalid(constraints: [constraint("in", [value])])
    end
  end

  test "delegate preserves a whitespace only constraint field" do
    assert_equal "   ", delegate(constraints: [constraint("eq", 1, field: "   ")]).reload.constraints.first["field"]
  end

  test "delegate does not trim or downcase a constraint field" do
    assert_equal " Amount ",
                 delegate(constraints: [constraint("eq", 1, field: " Amount ")]).reload.constraints.first["field"]
  end

  test "delegate preserves multiple constraints in caller order" do
    constraints = [constraint("lte", 100), constraint("eq", "JPY", field: "currency")]
    assert_equal constraints.map { |entry|
      entry.transform_keys(&:to_s)
    }, delegate(constraints: constraints).reload.constraints
  end

  test "delegate does not mutate the constraints array passed by the caller" do
    constraints = [constraint("eq", 1)]
    original = constraints.deep_dup
    delegate(constraints: constraints)
    assert_equal original, constraints
    refute_predicate constraints, :frozen?
  end

  test "delegate does not mutate a constraint hash passed by the caller" do
    entry = { field: :amount, operator: :eq, value: 1 }
    original = entry.dup
    delegate(constraints: [entry])
    assert_equal original, entry
    refute_predicate entry, :frozen?
  end

  test "delegate does not mutate an in value array passed by the caller" do
    values = [2, 1, 1]
    delegate(constraints: [constraint("in", values)])
    assert_equal [2, 1, 1], values
    refute_predicate values, :frozen?
  end

  test "delegate accepts nil expiration" do
    assert_nil delegate(expires_at: nil).reload.expires_at
  end

  test "delegate accepts future Time expiration" do
    expiration = Time.now + 3600
    assert_equal expiration, delegate(expires_at: expiration).reload.expires_at
  end

  test "delegate accepts future TimeWithZone expiration" do
    expiration = Time.current.in_time_zone("Asia/Tokyo") + 3600
    assert_equal expiration, delegate(expires_at: expiration).reload.expires_at
  end

  test "delegate rejects expiration equal to current time" do
    assert_invalid(expires_at: Time.current)
  end

  test "delegate rejects past expiration" do
    assert_invalid(expires_at: Time.current - 1)
  end

  { "string" => -> { (Time.current + 3600).iso8601 },
    "date" => -> { Date.current + 1 },
    "datetime" => -> { DateTime.current + 1 },
    "integer" => -> { Time.current.to_i + 3600 } }.each do |name, input|
    test "delegate rejects #{name} expiration without conversion" do
      assert_invalid(expires_at: instance_exec(&input))
    end
  end

  test "delegate returns a persisted delegation that can be retrieved" do
    assert_difference "ActingFor::Delegation.count", 1 do
      delegation = delegate
      assert_instance_of ActingFor::Delegation, delegation
      assert_predicate delegation, :persisted?
      assert_equal delegation, ActingFor::Delegation.find(delegation.id)
    end
  end

  test "delegate creates a delegation with nil revoked at" do
    assert_nil delegate.reload.revoked_at
  end

  test "delegate creates separate records for identical calls" do
    assert_difference "ActingFor::Delegation.count", 2 do
      first = delegate
      second = delegate
      refute_equal first.id, second.id
    end
  end

  test "delegate propagates model validation errors without wrapping" do
    validation = ->(record) { record.errors.add(:base, "host test validation failure") }
    ActingFor::Delegation.validate(validation)
    begin
      assert_raises(ActiveRecord::RecordInvalid) { delegate }
    ensure
      ActingFor::Delegation.skip_callback(:validate, :before, validation)
    end
  end

  test "delegate propagates database foreign key errors without wrapping" do
    ActingFor::Agent.where(id: @agent.id).delete_all
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActingFor::Delegation.transaction(requires_new: true) { delegate }
    end
  end

  private

  def delegate(**overrides)
    ActingFor.delegate(agent: @agent, principal: @principal, action: "purchase", effect: "allow", **overrides)
  end

  def assert_invalid(**overrides)
    assert_no_difference "ActingFor::Delegation.count" do
      assert_raises(ActingFor::InvalidRequestError) { delegate(**overrides) }
    end
  end

  def constraint(operator, value, field: "amount")
    { field: field, operator: operator, value: value }
  end
end

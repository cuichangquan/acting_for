require "test_helper"

class DelegationLifecycleTest < ActiveSupport::TestCase
  IMMUTABLE_ATTRIBUTES = %w[
    agent_id principal_type principal_id action resource_type resource_id
    constraints effect expires_at revoked_at
  ].freeze

  class Resource
    extend ActiveModel::Naming

    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  setup do
    travel_to Time.utc(2026, 9, 20, 12)
    @agent = ActingFor::Agent.create!(identifier: "delegation-lifecycle-agent")
    @principal = Principal.create!
  end

  {
    "agent" => -> { { agent_id: ActingFor::Agent.create!(identifier: "other-lifecycle-agent").id } },
    "action" => -> { { action: "refund" } },
    "resource type" => -> { { resource_type: "OtherResource" } },
    "resource id" => -> { { resource_id: "999" } },
    "constraints" => -> {
      {
        constraints: [
          { "field" => "amount", "operator" => "lte", "value" => 50_000 }
        ]
      }
    },
    "effect" => -> { { effect: "require_approval" } },
    "expiration" => -> { { expires_at: Time.current + 2.hours } },
    "revocation timestamp through ordinary update" => -> { { revoked_at: Time.current } }
  }.each do |name, changes|
    test "persisted delegation cannot change its #{name}" do
      delegation = resource_delegation
      original = delegation.attributes.slice(*IMMUTABLE_ATTRIBUTES)

      assert_raises(ActiveRecord::RecordInvalid) do
        delegation.update!(**instance_exec(&changes))
      end

      assert_equal original, delegation.reload.attributes.slice(*ActingFor::Delegation::IMMUTABLE_ATTRIBUTES)
    end
  end

  test "persisted delegation cannot change its principal" do
    delegation = resource_delegation
    original_type = delegation.principal_type
    original_id = delegation.principal_id

    assert_raises(ActiveRecord::RecordInvalid) do
      delegation.update!(principal: Principal.create!)
    end

    delegation.reload
    assert_equal original_type, delegation.principal_type
    assert_equal original_id, delegation.principal_id
  end

  test "revoke sets revoked at and updates updated at" do
    delegation = resource_delegation
    original_updated_at = delegation.updated_at
    revoke_time = Time.current + 1.minute

    travel_to(revoke_time) { delegation.revoke! }

    delegation.reload
    assert_equal revoke_time, delegation.revoked_at
    assert_equal revoke_time, delegation.updated_at
    assert_operator delegation.updated_at, :>, original_updated_at
  end

  test "revoke is idempotent and preserves the first timestamp" do
    delegation = resource_delegation
    first_time = Time.current + 1.minute
    second_time = Time.current + 2.minutes

    travel_to(first_time) { delegation.revoke! }
    first_revoked_at = delegation.revoked_at
    first_updated_at = delegation.updated_at

    travel_to(second_time) { delegation.revoke! }

    delegation.reload
    assert_equal first_revoked_at, delegation.revoked_at
    assert_equal first_updated_at, delegation.updated_at
  end

  test "revoke from a stale instance does not overwrite the first timestamp" do
    delegation = resource_delegation
    first_copy = ActingFor::Delegation.find(delegation.id)
    stale_copy = ActingFor::Delegation.find(delegation.id)
    first_time = Time.current + 1.minute
    later_time = Time.current + 2.minutes

    travel_to(first_time) { first_copy.revoke! }
    travel_to(later_time) { stale_copy.revoke! }

    stored = ActingFor::Delegation.find(delegation.id)
    assert_equal first_time, stored.revoked_at
    assert_equal first_time, stored.updated_at
  end

  test "revoke rejects an unsaved delegation" do
    delegation = ActingFor::Delegation.new

    assert_raises(ActiveRecord::RecordNotSaved) { delegation.revoke! }
  end

  test "revoked delegation no longer authorizes the action" do
    delegation = resource_delegation

    assert_equal :allow, authorize.status

    travel_to(Time.current + 1.minute) { delegation.revoke! }

    assert_equal :deny, authorize.status
  end

  test "revoking one duplicate delegation does not revoke another" do
    first = resource_delegation
    second = resource_delegation

    travel_to(Time.current + 1.minute) { first.revoke! }

    assert_predicate first.reload.revoked_at, :present?
    assert_nil second.reload.revoked_at
    assert_equal :allow, authorize.status
  end

  private

  def resource_delegation
    ActingFor.delegate(
      agent: @agent,
      principal: @principal,
      action: :purchase,
      resource: Resource.new(123),
      constraints: [{ field: :amount, operator: :lte, value: 10_000 }],
      effect: :allow,
      expires_at: Time.current + 1.day
    )
  end

  def authorize
    ActingFor.authorize(
      agent: @agent,
      principal: @principal,
      action: :purchase,
      resource: Resource.new(123),
      context: { amount: 800 }
    )
  end
end

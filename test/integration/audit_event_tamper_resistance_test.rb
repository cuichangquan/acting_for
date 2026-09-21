require "test_helper"

class AuditEventTamperResistanceTest < ActiveSupport::TestCase
  class Resource
    extend ActiveModel::Naming

    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  setup do
    travel_to Time.utc(2026, 9, 21, 12)
    @agent = ActingFor::Agent.create!(identifier: "audit-tamper-agent")
    @principal = Principal.create!
    @delegation = ActingFor.delegate(
      agent: @agent,
      principal: @principal,
      action: :purchase,
      resource: Resource.new(123),
      constraints: [{ field: :amount, operator: :lte, value: 10_000 }],
      effect: :allow
    )
  end

  {
    "agent id" => -> { { agent_id: ActingFor::Agent.create!(identifier: "other-audit-agent").id } },
    "agent identifier" => -> { { agent_identifier: "tampered-agent" } },
    "principal type" => -> { { principal_type: "OtherPrincipal" } },
    "principal id" => -> { { principal_id: "999" } },
    "action" => -> { { action: "refund" } },
    "resource type" => -> { { resource_type: "OtherResource" } },
    "resource id" => -> { { resource_id: "999" } },
    "decision" => -> { { decision: "deny" } },
    "reason code" => -> { { reason_code: "no_matching_delegation" } },
    "matched delegation ids" => -> { { matched_delegation_ids: [] } },
    "sanitized context" => -> { { sanitized_context: { "amount" => 99_999 } } }
  }.each do |name, changes|
    test "persisted audit event cannot change its #{name}" do
      event = authorize_and_audit
      original = event.attributes

      assert_raises(ActiveRecord::ReadOnlyRecord) do
        event.update!(**instance_exec(&changes))
      end

      assert_equal original, event.reload.attributes
    end
  end

  test "persisted audit event cannot be destroyed" do
    event = authorize_and_audit

    assert_no_difference "ActingFor::AuditEvent.count" do
      assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy! }
    end

    assert ActingFor::AuditEvent.exists?(event.id)
  end

  test "a later authorization inserts a new audit without rewriting the existing audit" do
    first = authorize_and_audit(amount: 800)
    first_snapshot = first.attributes

    assert_difference "ActingFor::AuditEvent.count", 1 do
      assert_equal :allow, authorize(amount: 700).status
    end

    assert_equal first_snapshot, first.reload.attributes
    refute_equal first.id, ActingFor::AuditEvent.order(:id).last.id
  end

  test "audit snapshot survives later agent and delegation changes" do
    event = authorize_and_audit
    original_identifier = event.agent_identifier
    original_matched_ids = event.matched_delegation_ids
    original_decision = event.decision

    @agent.update!(identifier: "renamed-after-audit")
    travel_to(Time.current + 1.minute) { @delegation.revoke! }

    event.reload
    assert_equal original_identifier, event.agent_identifier
    assert_equal original_matched_ids, event.matched_delegation_ids
    assert_equal original_decision, event.decision
  end

  private

  def authorize_and_audit(amount: 800)
    authorize(amount:)
    ActingFor::AuditEvent.order(:id).last
  end

  def authorize(amount:)
    ActingFor.authorize(
      agent: @agent,
      principal: @principal,
      action: :purchase,
      resource: Resource.new(123),
      context: { amount: },
      audit_context_keys: [:amount]
    )
  end
end

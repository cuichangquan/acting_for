require "test_helper"

class DatabaseConstraintSecurityTest < ActiveSupport::TestCase
  setup do
    @agent = ActingFor::Agent.create!(identifier: "database-constraint-agent")
    @principal = Principal.create!
  end

  test "database rejects duplicate agent identifiers" do
    assert_db_rejects do
      ActingFor::Agent.insert_all!([
        {
          identifier: @agent.identifier,
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    end
  end

  test "database rejects delegation with an orphan agent id" do
    attributes = valid_delegation_attributes.merge(
      agent_id: ActingFor::Agent.maximum(:id).to_i + 1_000_000
    )

    assert_db_rejects { ActingFor::Delegation.insert_all!([attributes]) }
  end

  test "database rejects delegation with an invalid effect" do
    assert_db_rejects do
      ActingFor::Delegation.insert_all!([
        valid_delegation_attributes.merge(effect: "deny")
      ])
    end
  end

  test "database rejects delegation resource id without resource type" do
    assert_db_rejects do
      ActingFor::Delegation.insert_all!([
        valid_delegation_attributes.merge(resource_type: nil, resource_id: "123")
      ])
    end
  end

  test "database rejects audit event with an invalid decision" do
    assert_db_rejects do
      ActingFor::AuditEvent.insert_all!([
        valid_audit_attributes.merge(decision: "unknown")
      ])
    end
  end

  test "database rejects audit event with an invalid reason code" do
    assert_db_rejects do
      ActingFor::AuditEvent.insert_all!([
        valid_audit_attributes.merge(reason_code: "unknown_reason")
      ])
    end
  end

  test "database rejects null required audit action" do
    assert_db_rejects do
      ActingFor::AuditEvent.insert_all!([
        valid_audit_attributes.merge(action: nil)
      ])
    end
  end

  private

  def assert_db_rejects(&block)
    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.transaction(requires_new: true, &block)
    end
  end

  def valid_delegation_attributes
    {
      agent_id: @agent.id,
      principal_type: @principal.class.polymorphic_name,
      principal_id: @principal.id.to_s,
      action: "purchase",
      resource_type: nil,
      resource_id: nil,
      effect: "allow",
      constraints: [],
      expires_at: nil,
      revoked_at: nil,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def valid_audit_attributes
    {
      agent_id: @agent.id,
      agent_identifier: @agent.identifier,
      principal_type: @principal.class.polymorphic_name,
      principal_id: @principal.id.to_s,
      action: "purchase",
      resource_type: nil,
      resource_id: nil,
      decision: "deny",
      reason_code: "no_matching_delegation",
      matched_delegation_ids: [],
      sanitized_context: {},
      created_at: Time.current
    }
  end
end

require "test_helper"

class HostAuthorizationBoundaryTest < ActiveSupport::TestCase
  setup do
    @agent = ActingFor::Agent.create!(identifier: "host-boundary-agent")
    @principal = Principal.create!
    @permissions = []
    @executions = []
    @approvals = []
    @operation = HostAuthorizedOperation.new(
      host_authorized: ->(principal, action, resource) { @permissions.include?([principal.id, action, resource.id]) },
      business_logic: -> { @executions << :purchase },
      approval_boundary: ->(decision) { @approvals << decision.status }
    )
  end

  test "host deny stops business logic even when ActingFor allows" do
    delegate
    assert_equal :allow, authorize.status
    assert_equal :stopped, operate
    assert_empty @executions
    assert_empty @approvals
  end

  test "host allow and ActingFor allow execute business logic" do
    grant
    delegate
    assert_equal :executed, operate
    assert_equal [:purchase], @executions
    assert_empty @approvals
  end

  test "principal without host permission stops despite require approval" do
    delegate(effect: :require_approval)
    assert_equal :require_approval, authorize.status
    assert_equal :stopped, operate
    assert_empty @executions
    assert_empty @approvals
  end

  test "principal with host permission passes require approval to workflow boundary without execution" do
    grant
    delegate(effect: :require_approval)
    assert_equal :approval_required, operate
    assert_empty @executions
    assert_equal [:require_approval], @approvals
  end

  %i[allow require_approval].each do |effect|
    test "loss of current host permission stops an existing #{effect} delegation" do
      grant
      delegation = delegate(effect: effect)
      @permissions.clear
      assert_predicate delegation.reload, :persisted?
      assert_nil delegation.revoked_at
      assert_equal effect, authorize.status
      assert_equal :stopped, operate
      assert_empty @executions
      assert_empty @approvals
    end
  end

  test "host permission alone cannot execute without a matching delegation" do
    grant
    assert_equal :stopped, operate
    assert_empty @executions
    assert_empty @approvals
    assert_equal "deny", ActingFor::AuditEvent.sole.decision
  end

  test "audit failure interrupts the host before business or approval callbacks" do
    grant
    delegate
    validation = ->(record) { record.errors.add(:base, "simulated audit failure") }
    ActingFor::AuditEvent.validate(validation)
    begin
      assert_raises(ActingFor::AuditPersistenceError) { operate }
      assert_empty @executions
      assert_empty @approvals
    ensure
      ActingFor::AuditEvent.skip_callback(:validate, :before, validation)
    end
  end

  private

  def grant
    @permissions << [@principal.id, :purchase, @principal.id]
  end

  def inputs
    { agent: @agent, principal: @principal, action: :purchase, resource: @principal }
  end

  def delegate(effect: :allow)
    ActingFor.delegate(**inputs, effect: effect)
  end

  def authorize
    ActingFor.authorize(**inputs)
  end

  def operate
    @operation.call(**inputs)
  end
end

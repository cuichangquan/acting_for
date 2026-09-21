require "test_helper"

class DelegationManagementBoundaryTest < ActiveSupport::TestCase
  setup do
    @agent = ActingFor::Agent.create!(identifier: "delegation-management-agent")
    @principal = Principal.create!
    @caller = Principal.create!
    @permissions = []
    @manager = HostDelegationManager.new(
      host_authorized: lambda do |caller, action, principal|
        @permissions.include?([caller.id, action, principal.id])
      end
    )
  end

  test "host deny prevents delegation creation" do
    assert_no_difference "ActingFor::Delegation.count" do
      assert_equal :stopped, create_delegation
    end
  end

  test "host allow permits delegation creation" do
    grant(:delegate)

    assert_difference "ActingFor::Delegation.count", 1 do
      assert_instance_of ActingFor::Delegation, create_delegation
    end
  end

  test "host deny prevents revocation" do
    grant(:delegate)
    delegation = create_delegation

    assert_equal :stopped, @manager.revoke(caller: @caller, delegation: delegation)
    assert_nil delegation.reload.revoked_at
  end

  test "host allow permits revocation" do
    grant(:delegate)
    delegation = create_delegation
    grant(:revoke)

    result = @manager.revoke(caller: @caller, delegation: delegation)

    assert_equal delegation.id, result.id
    assert_not_nil delegation.reload.revoked_at
  end

  private

  def grant(action)
    @permissions << [@caller.id, action, @principal.id]
  end

  def create_delegation
    @manager.delegate(
      caller: @caller,
      agent: @agent,
      principal: @principal,
      action: :purchase,
      effect: :allow
    )
  end
end

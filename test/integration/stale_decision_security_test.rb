require "test_helper"

class StaleDecisionSecurityTest < ActiveSupport::TestCase
  class Resource
    extend ActiveModel::Naming

    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  setup do
    travel_to Time.utc(2026, 9, 21, 12)
    @agent = ActingFor::Agent.create!(identifier: "stale-decision-agent")
    @principal = Principal.create!
    @resource = Resource.new(123)
  end

  test "old allow remains historical after revoke but reauthorization denies" do
    delegation = delegate
    first = authorize

    assert_equal :allow, first.status
    delegation.revoke!
    second = authorize

    assert_equal :allow, first.status
    assert_equal :deny, second.status
    assert_equal %w[allow deny], ActingFor::AuditEvent.order(:id).pluck(:decision)
  end

  test "old allow does not represent authority after expiration" do
    expiration = Time.current + 60
    delegate(expires_at: expiration)
    first = authorize

    travel_to expiration
    second = authorize

    assert_equal :allow, first.status
    assert_equal :deny, second.status
  end

  test "changed context requires a fresh authorization decision" do
    delegate(constraints: [{ field: :amount, operator: :lte, value: 100 }])
    first = authorize(context: { amount: 100 })
    second = authorize(context: { amount: 101 })

    assert_equal :allow, first.status
    assert_equal :deny, second.status
  end

  private

  def delegate(**overrides)
    ActingFor.delegate(
      agent: @agent,
      principal: @principal,
      action: :purchase,
      resource: @resource,
      effect: :allow,
      **overrides
    )
  end

  def authorize(**overrides)
    ActingFor.authorize(
      agent: @agent,
      principal: @principal,
      action: :purchase,
      resource: @resource,
      **overrides
    )
  end
end

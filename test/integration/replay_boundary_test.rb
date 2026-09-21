require "test_helper"

class ReplayBoundaryTest < ActiveSupport::TestCase
  setup do
    @agent = ActingFor::Agent.create!(identifier: "replay-boundary-agent")
    @principal = Principal.create!
    ActingFor.delegate(
      agent: @agent,
      principal: @principal,
      action: :purchase,
      effect: :allow
    )
  end

  test "repeated authorization is evaluated independently and audited each time" do
    decisions = []

    assert_difference "ActingFor::AuditEvent.count", 2 do
      2.times { decisions << authorize }
    end

    assert_equal %i[allow allow], decisions.map(&:status)
    assert_equal %w[allow allow], ActingFor::AuditEvent.order(:id).pluck(:decision)
  end

  test "identical authorization calls do not act as an exactly once operation token" do
    first = authorize
    second = authorize

    assert_equal :allow, first.status
    assert_equal :allow, second.status
    refute_same first, second
  end

  private

  def authorize
    ActingFor.authorize(
      agent: @agent,
      principal: @principal,
      action: :purchase
    )
  end
end

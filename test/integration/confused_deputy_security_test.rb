require "test_helper"

class ConfusedDeputySecurityTest < ActiveSupport::TestCase
  class Resource
    extend ActiveModel::Naming

    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  class OtherResource < Resource
  end

  setup do
    @agent_a = ActingFor::Agent.create!(identifier: "confused-deputy-agent-a")
    @agent_b = ActingFor::Agent.create!(identifier: "confused-deputy-agent-b")
    @principal_a = Principal.create!
    @principal_b = Principal.create!
    @resource = Resource.new(123)

    ActingFor.delegate(
      agent: @agent_a,
      principal: @principal_a,
      action: :purchase,
      resource: @resource,
      effect: :allow
    )
  end

  test "only the exact agent principal resource binding can use the delegation" do
    cases = [
      [@agent_a, @principal_a, Resource.new(123), :allow],
      [@agent_b, @principal_a, Resource.new(123), :deny],
      [@agent_a, @principal_b, Resource.new(123), :deny],
      [@agent_a, @principal_a, Resource.new(456), :deny],
      [@agent_a, @principal_a, OtherResource.new(123), :deny]
    ]

    cases.each do |agent, principal, resource, expected|
      assert_equal expected, authorize(agent:, principal:, resource:).status
    end
  end

  test "same agent cannot reuse one principal delegation for another principal" do
    assert_equal :allow, authorize(agent: @agent_a, principal: @principal_a, resource: @resource).status
    assert_equal :deny, authorize(agent: @agent_a, principal: @principal_b, resource: @resource).status
  end

  private

  def authorize(agent:, principal:, resource:)
    ActingFor.authorize(
      agent: agent,
      principal: principal,
      action: :purchase,
      resource: resource
    )
  end
end

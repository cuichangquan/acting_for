require "test_helper"

class ContextTrustBoundaryTest < ActiveSupport::TestCase
  test "authorize evaluates host supplied context without fetching or inspecting the host resource" do
    agent = ActingFor::Agent.create!(identifier: "context-boundary-agent")
    principal = Principal.create!
    resource = Principal.create!
    # The resource offers identity only to Core; business facts remain Host-owned.
    resource.define_singleton_method(:amount) { raise "Core read host amount" }
    resource.define_singleton_method(:owner) { raise "Core read host owner" }
    resource.define_singleton_method(:reload) { raise "Core reloaded host resource" }
    inputs = { agent: agent, principal: principal, action: :purchase, resource: resource }
    ActingFor.delegate(**inputs, effect: :allow,
                                 constraints: [{ field: :amount, operator: :lte, value: 100 }])
    host_queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      host_queries << payload[:sql] if payload[:sql].match?(/\bFROM\s+"?principals"?/i)
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      assert_equal :allow, ActingFor.authorize(**inputs, context: { amount: 100 }).status
      assert_equal :deny, ActingFor.authorize(**inputs, context: { amount: 101 }).status
    end
    assert_empty host_queries
  end
end

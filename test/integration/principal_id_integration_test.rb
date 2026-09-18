require "test_helper"
require "securerandom"

class PrincipalIdIntegrationTest < ActiveSupport::TestCase
  { bigint: -> { Principal.create! }, uuid: -> { UuidPrincipal.create!(id: SecureRandom.uuid) } }.each do |type, create|
    test "#{type} principal id round trips through delegation association and authorization" do
      principal = instance_exec(&create)
      agent = ActingFor::Agent.create!(identifier: "#{type}-principal-agent")
      delegation = ActingFor.delegate(agent: agent, principal: principal, action: :purchase, effect: :allow)
      stored = delegation.reload
      assert_equal principal.id.to_s, stored.principal_id
      assert_equal principal, stored.principal
      assert_equal :allow, ActingFor.authorize(agent: agent, principal: stored.principal, action: :purchase).status
      assert_equal principal.id.to_s, ActingFor::AuditEvent.sole.principal_id
      assert_equal type == :uuid ? :uuid : :integer, principal.class.columns_hash.fetch("id").type
    end
  end
end

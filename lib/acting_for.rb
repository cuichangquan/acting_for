require "acting_for/version"
require "acting_for/engine"
require "acting_for/errors"
require "acting_for/decision"

module ActingFor
  def self.authorize(agent:, principal:, action:, resource: nil, context: {}, audit_context_keys: [])
    Internal::Authorization.call(
      agent: agent, principal: principal, action: action, resource: resource, context: context,
      audit_context_keys: audit_context_keys
    )
  end

  def self.delegate(agent:, principal:, action:, resource: nil, constraints: [], effect:, expires_at: nil)
    Internal::DelegationCreator.call(
      agent: agent, principal: principal, action: action, resource: resource,
      constraints: constraints, effect: effect, expires_at: expires_at
    )
  end

  def self.current_time
    Time.current
  end
end

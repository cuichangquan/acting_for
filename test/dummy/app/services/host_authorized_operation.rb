# Minimal host boundary example, not a workflow or a Core authorization API.
class HostAuthorizedOperation
  def initialize(host_authorized:, business_logic:, approval_boundary:)
    @host_authorized = host_authorized
    @business_logic = business_logic
    @approval_boundary = approval_boundary
  end

  def call(agent:, principal:, action:, resource: nil, context: {})
    return :stopped unless @host_authorized.call(principal, action, resource)

    decision = ActingFor.authorize(agent: agent, principal: principal,
                                   action: action, resource: resource, context: context)
    if decision.allowed?
      @business_logic.call
      :executed
    elsif decision.approval_required?
      @approval_boundary.call(decision)
      :approval_required
    else
      :stopped
    end
  end
end

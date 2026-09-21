# Minimal host boundary example, not a Core delegation authorization API.
class HostDelegationManager
  def initialize(host_authorized:)
    @host_authorized = host_authorized
  end

  def delegate(caller:, **attributes)
    return :stopped unless @host_authorized.call(caller, :delegate, attributes.fetch(:principal))

    ActingFor.delegate(**attributes)
  end

  def revoke(caller:, delegation:)
    return :stopped unless @host_authorized.call(caller, :revoke, delegation.principal)

    delegation.revoke!
  end
end

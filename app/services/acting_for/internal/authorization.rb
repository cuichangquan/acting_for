module ActingFor
  module Internal
    class Authorization
      class << self
        def call(agent:, principal:, action:, resource_type:, resource_id:, context:)
          matches = candidate_delegations(
            agent: agent,
            principal: principal,
            action: action,
            resource_type: resource_type
          ).select do |delegation|
            resource_matches?(delegation, resource_type, resource_id) &&
              ConstraintEvaluator.call(constraints: delegation.constraints, context: context)
          end

          ActingFor::Decision.new(decision_status(matches))
        end

        private

        def candidate_delegations(agent:, principal:, action:, resource_type:)
          ActingFor::Delegation
            .where(
              agent: agent,
              principal: principal,
              action: action,
              resource_type: resource_type,
              revoked_at: nil
            )
            .where("expires_at IS NULL OR expires_at > ?", ActingFor.current_time)
        end

        def resource_matches?(delegation, resource_type, resource_id)
          return delegation.resource_id.nil? && resource_id.nil? if resource_type.nil?
          return false unless delegation.resource_type == resource_type
          return delegation.resource_id.nil? if resource_id.nil?

          delegation.resource_id.nil? || delegation.resource_id == resource_id
        end

        def decision_status(matches)
          return :require_approval if matches.any? { |delegation| delegation.effect == "require_approval" }
          return :allow if matches.any? { |delegation| delegation.effect == "allow" }

          :deny
        end
      end
    end
  end
end

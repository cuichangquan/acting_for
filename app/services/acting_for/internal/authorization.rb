require "bigdecimal"

module ActingFor
  module Internal
    class Authorization
      FORBIDDEN_AUDIT_CONTEXT_KEYS = %i[
        password password_confirmation token access_token refresh_token
        api_key secret client_secret credential
      ].freeze
      private_constant :FORBIDDEN_AUDIT_CONTEXT_KEYS

      class << self
        def call(agent:, principal:, action:, resource:, context:, audit_context_keys:)
          unless agent.is_a?(ActingFor::Agent) && agent.persisted?
            raise InvalidRequestError, "agent must be a persisted ActingFor::Agent"
          end
          unless principal.is_a?(ActiveRecord::Base) && principal.persisted?
            raise InvalidRequestError, "principal must be a persisted ActiveRecord record"
          end

          action = string_value(action, "action")
          raise InvalidRequestError, "action must not be blank" if action.blank?
          resource_type, resource_id = resource_identity(resource)
          raise InvalidRequestError, "context must be a Hash" unless context.is_a?(Hash)

          audit_context = sanitized_context(context, audit_context_keys)

          matches = candidate_delegations(
            agent: agent,
            principal: principal,
            action: action,
            resource_type: resource_type
          ).select do |delegation|
            resource_matches?(delegation, resource_type, resource_id) &&
              ConstraintEvaluator.call(constraints: delegation.constraints, context: context)
          end

          decision = ActingFor::Decision.new(decision_status(matches))
          audit_attributes = audit_event_attributes(
            agent: agent,
            principal: principal,
            action: action,
            resource_type: resource_type,
            resource_id: resource_id,
            decision: decision,
            matches: matches,
            sanitized_context: audit_context
          )
          persist_audit_event!(audit_attributes)

          decision
        end

        private

        def string_value(value, name)
          return value if value.is_a?(String)
          return value.to_s if value.is_a?(Symbol)

          raise InvalidRequestError, "#{name} must be a String or Symbol"
        end

        def resource_identity(resource)
          return [nil, nil] if resource.nil?

          klass = resource.is_a?(Class) ? resource : resource.class
          unless klass.respond_to?(:model_name)
            raise InvalidRequestError, "resource class must provide model_name"
          end
          model_name = klass.model_name
          unless model_name.respond_to?(:name)
            raise InvalidRequestError, "resource model_name must provide name"
          end
          resource_type = model_name.name
          return [resource_type, nil] if resource.is_a?(Class)

          unless resource.respond_to?(:id)
            raise InvalidRequestError, "resource instance must provide id"
          end
          id = resource.id
          raise InvalidRequestError, "resource id must not be nil" if id.nil?

          resource_id = id.to_s
          raise InvalidRequestError, "resource id must not be empty" if resource_id.empty?

          [resource_type, resource_id]
        end

        def sanitized_context(context, audit_context_keys)
          unless audit_context_keys.is_a?(Array) &&
              audit_context_keys.all? { |key| key.is_a?(Symbol) }
            raise InvalidRequestError, "audit_context_keys must be an Array of Symbols"
          end

          keys = audit_context_keys.uniq
          forbidden_key = keys.find { |key| FORBIDDEN_AUDIT_CONTEXT_KEYS.include?(key) }
          if forbidden_key
            raise InvalidRequestError, "audit_context_keys contains forbidden key: #{forbidden_key}"
          end

          keys.each_with_object({}) do |key, sanitized|
            next unless exact_symbol_key?(context, key)

            sanitized[key.to_s] = sanitized_audit_value(context[key], key)
          end
        end

        def exact_symbol_key?(context, key)
          context.each_key.any? { |existing_key| existing_key.is_a?(Symbol) && existing_key == key }
        end

        def sanitized_audit_value(value, key)
          return value.to_s("F") if value.is_a?(BigDecimal)
          return value if value.nil? ||
            value.is_a?(String) ||
            value.is_a?(Integer) ||
            value.is_a?(Float) ||
            value.is_a?(TrueClass) ||
            value.is_a?(FalseClass)

          raise InvalidRequestError, "unsupported audit context value for #{key}"
        end

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

        def audit_event_attributes(
          agent:, principal:, action:, resource_type:, resource_id:, decision:, matches:, sanitized_context:
        )
          decision_value = decision.status.to_s

          {
            agent_id: agent.id,
            agent_identifier: agent.identifier,
            principal_type: principal.class.polymorphic_name,
            principal_id: principal.id.to_s,
            action: action,
            resource_type: resource_type,
            resource_id: resource_id,
            decision: decision_value,
            reason_code: ActingFor::AuditEvent::DECISION_REASONS.fetch(decision_value),
            matched_delegation_ids: matches.map(&:id).sort,
            sanitized_context: sanitized_context
          }
        end

        def persist_audit_event!(attributes)
          ActingFor::AuditEvent.create!(attributes)
        rescue ActiveRecord::ActiveRecordError => error
          raise ActingFor::AuditPersistenceError, "Failed to persist audit event", cause: error
        end
      end
    end
  end
end

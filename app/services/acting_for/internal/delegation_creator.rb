module ActingFor
  module Internal
    class DelegationCreator
      class << self
        def call(agent:, principal:, action:, resource:, constraints:, effect:, expires_at:)
          unless agent.is_a?(ActingFor::Agent) && agent.persisted?
            raise InvalidRequestError, "agent must be a persisted ActingFor::Agent"
          end
          unless principal.is_a?(ActiveRecord::Base) && principal.persisted?
            raise InvalidRequestError, "principal must be a persisted ActiveRecord record"
          end

          action = string_value(action, "action")
          raise InvalidRequestError, "action must not be blank" if action.blank?

          resource_type, resource_id = resource_identity(resource)
          effect = string_value(effect, "effect")
          unless %w[allow require_approval].include?(effect)
            raise InvalidRequestError, "effect must be allow or require_approval"
          end
          constraints = canonical_constraints(constraints)
          validate_expiration(expires_at)

          ActingFor::Delegation.create!(
            agent: agent, principal: principal, action: action,
            resource_type: resource_type, resource_id: resource_id,
            constraints: constraints, effect: effect,
            expires_at: expires_at, revoked_at: nil
          )
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

        def canonical_constraints(constraints)
          raise InvalidRequestError, "constraints must be an Array" unless constraints.is_a?(Array)

          constraints.map.with_index do |constraint, index|
            name = "constraints[#{index}]"
            raise InvalidRequestError, "#{name} must be a Hash" unless constraint.is_a?(Hash)

            canonical = {}
            constraint.each do |key, value|
              key = string_value(key, "#{name} key")
              raise InvalidRequestError, "#{name} has duplicate key #{key}" if canonical.key?(key)

              canonical[key] = value
            end
            unless canonical.keys.sort == %w[field operator value]
              raise InvalidRequestError, "#{name} must have exactly field, operator and value keys"
            end

            field = string_value(canonical["field"], "#{name} field")
            raise InvalidRequestError, "#{name} field must not be empty" if field.empty?

            operator = string_value(canonical["operator"], "#{name} operator")
            value = canonical["value"]
            valid_value = case operator
            when "eq"
              scalar_value?(value)
            when "lt", "lte", "gt", "gte"
              value.is_a?(Integer)
            when "in"
              value.is_a?(Array) && value.all? { |element| scalar_value?(element) }
            else
              raise InvalidRequestError, "#{name} operator must be eq, lt, lte, gt, gte or in"
            end
            unless valid_value
              raise InvalidRequestError, "#{name} value has an invalid type for #{operator}"
            end

            { "field" => field, "operator" => operator, "value" => operator == "in" ? value.dup : value }
          end
        end

        def scalar_value?(value)
          value.is_a?(String) || value.is_a?(Integer) || value.is_a?(TrueClass) || value.is_a?(FalseClass)
        end

        def validate_expiration(expires_at)
          return if expires_at.nil?

          unless expires_at.is_a?(Time) || expires_at.is_a?(ActiveSupport::TimeWithZone)
            raise InvalidRequestError, "expires_at must be a Time or ActiveSupport::TimeWithZone"
          end
          unless expires_at > ActingFor.current_time
            raise InvalidRequestError, "expires_at must be in the future"
          end
        end
      end
    end
  end
end

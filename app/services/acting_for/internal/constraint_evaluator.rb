module ActingFor
  module Internal
    class ConstraintEvaluator
      CONSTRAINT_KEYS = %w[field operator value].freeze
      private_constant :CONSTRAINT_KEYS

      class << self
        def call(constraints:, context:)
          return false unless constraints.is_a?(Array) && context.is_a?(Hash)

          constraints.all? { |constraint| constraint_matches?(constraint, context) }
        end

        private

        def constraint_matches?(constraint, context)
          return false unless canonical_constraint?(constraint)

          field = constraint["field"]
          key = field.to_sym
          return false unless context.key?(key)

          actual = context[key]
          return false if actual.nil?

          expected = constraint["value"]

          case constraint["operator"]
          when "eq"
            same_scalar_type?(actual, expected) && actual == expected
          when "lt"
            integer_comparison?(actual, expected) && actual < expected
          when "lte"
            integer_comparison?(actual, expected) && actual <= expected
          when "gt"
            integer_comparison?(actual, expected) && actual > expected
          when "gte"
            integer_comparison?(actual, expected) && actual >= expected
          when "in"
            expected.any? do |candidate|
              same_scalar_type?(actual, candidate) && actual == candidate
            end
          else
            false
          end
        end

        def canonical_constraint?(constraint)
          return false unless constraint.is_a?(Hash)
          return false unless constraint.keys.all? { |key| key.is_a?(String) }
          return false unless constraint.keys.sort == CONSTRAINT_KEYS

          field = constraint["field"]
          return false unless field.is_a?(String) && !field.empty?

          value = constraint["value"]

          case constraint["operator"]
          when "eq"
            scalar_value?(value)
          when "lt", "lte", "gt", "gte"
            value.is_a?(Integer)
          when "in"
            value.is_a?(Array) && value.all? { |element| scalar_value?(element) }
          else
            false
          end
        end

        def integer_comparison?(actual, expected)
          actual.is_a?(Integer) && expected.is_a?(Integer)
        end

        def same_scalar_type?(actual, expected)
          return actual.is_a?(String) if expected.is_a?(String)
          return actual.is_a?(Integer) if expected.is_a?(Integer)
          return boolean_value?(actual) if boolean_value?(expected)

          false
        end

        def scalar_value?(value)
          value.is_a?(String) || value.is_a?(Integer) || boolean_value?(value)
        end

        def boolean_value?(value)
          value.is_a?(TrueClass) || value.is_a?(FalseClass)
        end
      end
    end
  end
end

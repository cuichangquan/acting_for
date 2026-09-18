module ActingFor
  class Delegation < ApplicationRecord
    IMMUTABLE_ATTRIBUTES = %w[
      agent_id principal_type principal_id action resource_type resource_id
      constraints effect expires_at revoked_at
    ].freeze
    CONSTRAINT_KEYS = %w[field operator value].freeze

    belongs_to :agent, class_name: "ActingFor::Agent"
    belongs_to :principal, polymorphic: true

    validates :agent, :principal, :action, :effect, presence: true
    validates :effect, inclusion: { in: %w[allow require_approval] }
    validate :resource_scope
    validate :canonical_constraints
    validate :initial_timestamps, on: :create
    validate :immutable_attributes, on: :update

    def revoke!
      raise ActiveRecord::RecordNotSaved.new("Cannot revoke an unsaved delegation", self) unless persisted?

      time = ActingFor.current_time
      self.class.where(id: id, revoked_at: nil).update_all(revoked_at: time, updated_at: time)
      reload
    end

    private

    def resource_scope
      errors.add(:resource_type, "is required when resource_id is set") if resource_type.nil? && !resource_id.nil?
    end

    def initial_timestamps
      if expires_at && expires_at <= ActingFor.current_time
        errors.add(:expires_at, "must be in the future")
      end
      errors.add(:revoked_at, "must be nil on creation") unless revoked_at.nil?
    end

    def immutable_attributes
      IMMUTABLE_ATTRIBUTES.each do |attribute|
        errors.add(attribute, "cannot be changed") if will_save_change_to_attribute?(attribute)
      end
    end

    def canonical_constraints
      # JSON casting stringifies Hash keys; also check the original assigned value.
      values = [constraints]
      values << read_attribute_before_type_cast(:constraints) if constraints_came_from_user?
      unless values.all? { |value| value.is_a?(Array) && value.all? { |entry| canonical_constraint?(entry) } }
        errors.add(:constraints, "must be an Array of canonical constraints")
      end
    end

    def canonical_constraint?(entry)
      return false unless entry.is_a?(Hash) && entry.keys.size == 3 && (CONSTRAINT_KEYS - entry.keys).empty?
      return false unless entry["field"].is_a?(String) && !entry["field"].empty?

      value = entry["value"]
      case entry["operator"]
      when "eq"
        scalar_constraint_value?(value)
      when "lt", "lte", "gt", "gte"
        value.is_a?(Integer)
      when "in"
        value.is_a?(Array) && value.all? { |element| scalar_constraint_value?(element) }
      else
        false
      end
    end

    def scalar_constraint_value?(value)
      value.is_a?(String) || value.is_a?(Integer) || value.is_a?(TrueClass) || value.is_a?(FalseClass)
    end
  end
end

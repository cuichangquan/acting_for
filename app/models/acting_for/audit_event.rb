module ActingFor
  class AuditEvent < ApplicationRecord
    DECISION_REASONS = {
      "allow" => "delegation_allowed",
      "require_approval" => "delegation_requires_approval",
      "deny" => "no_matching_delegation"
    }.freeze

    validates :agent_id, :agent_identifier, :principal_type, :principal_id,
              :action, :decision, :reason_code, presence: true
    validates :decision, inclusion: { in: DECISION_REASONS.keys }
    validates :reason_code, inclusion: { in: DECISION_REASONS.values }
    validate :decision_reason_pair
    validate :resource_scope
    validate :matched_delegations
    validate :context_format

    def readonly?
      persisted? || super
    end

    private

    def decision_reason_pair
      errors.add(:reason_code, "does not match decision") unless DECISION_REASONS[decision] == reason_code
    end

    def resource_scope
      errors.add(:resource_type, "is required when resource_id is set") if resource_type.nil? && !resource_id.nil?
    end

    def matched_delegations
      ids = matched_delegation_ids
      unless ids.is_a?(Array) && ids.all?(Integer) && ids.uniq.length == ids.length
        errors.add(:matched_delegation_ids, "must be an Array of unique Integers")
        return
      end

      if decision == "deny" && !ids.empty?
        errors.add(:matched_delegation_ids, "must be empty for deny")
      elsif %w[allow require_approval].include?(decision) && ids.empty?
        errors.add(:matched_delegation_ids, "must not be empty for allow or require_approval")
      end
    end

    def context_format
      errors.add(:sanitized_context, "must be a Hash") unless sanitized_context.is_a?(Hash)
    end
  end
end

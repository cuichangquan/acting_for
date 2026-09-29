module ActingFor
  class Decision
    STATUSES = %i[allow deny require_approval].freeze
    REASON_CODES = {
      allow: :delegation_allowed,
      deny: :no_matching_delegation,
      require_approval: :delegation_requires_approval
    }.freeze
    private_constant :STATUSES, :REASON_CODES

    attr_reader :status, :reason_code

    def initialize(status)
      raise ArgumentError, "invalid decision status" unless STATUSES.include?(status)

      @status = status
      @reason_code = REASON_CODES.fetch(status)
      freeze
    end

    def allowed?
      status == :allow
    end

    def denied?
      status == :deny
    end

    def approval_required?
      status == :require_approval
    end
  end
end

module ActingFor
  class Decision
    STATUSES = %i[allow deny require_approval].freeze
    private_constant :STATUSES

    attr_reader :status

    def initialize(status)
      raise ArgumentError, "invalid decision status" unless STATUSES.include?(status)

      @status = status
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

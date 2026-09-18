module ActingFor
  class Error < StandardError
  end

  class InvalidRequestError < Error
  end

  class InternalError < Error
  end

  class AuditPersistenceError < InternalError
  end
end

require "test_helper"

class SensitiveContextSecurityTest < ActiveSupport::TestCase
  SECRET = "super-secret-value".freeze

  class Resource
    extend ActiveModel::Naming

    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  setup do
    @agent = ActingFor::Agent.create!(identifier: "sensitive-context-agent")
    @principal = Principal.create!
    @resource = Resource.new(123)
  end

  test "audit context defaults to empty even when raw context contains secrets" do
    authorize(context: { amount: 100, access_token: SECRET, password: SECRET })

    assert_equal({}, audit.sanitized_context)
    refute_includes audit.sanitized_context.to_json, SECRET
  end

  test "audit stores only explicitly selected safe context" do
    authorize(
      context: { amount: 100, api_key: SECRET, nested: { secret: SECRET } },
      audit_context_keys: [:amount]
    )

    assert_equal({ "amount" => 100 }, audit.sanitized_context)
    refute_includes audit.sanitized_context.to_json, SECRET
  end

  test "forbidden audit key is rejected without exposing its value" do
    error = assert_raises(ActingFor::InvalidRequestError) do
      authorize(context: { access_token: SECRET }, audit_context_keys: [:access_token])
    end

    refute_includes error.message, SECRET
    assert_empty ActingFor::AuditEvent.all
  end

  private

  def authorize(**overrides)
    ActingFor.authorize(
      agent: @agent,
      principal: @principal,
      action: :purchase,
      resource: @resource,
      **overrides
    )
  end

  def audit
    ActingFor::AuditEvent.sole
  end
end

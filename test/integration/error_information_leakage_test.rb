require "test_helper"

class ErrorInformationLeakageTest < ActiveSupport::TestCase
  SECRET = "secret-do-not-expose".freeze

  class Resource
    extend ActiveModel::Naming

    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  class SensitiveObject
    def inspect
      "SensitiveObject<#{SECRET}>"
    end
  end

  setup do
    @agent = ActingFor::Agent.create!(identifier: "error-leakage-agent")
    @principal = Principal.create!
    @resource = Resource.new(123)
  end

  test "invalid request does not include sensitive context value" do
    error = assert_raises(ActingFor::InvalidRequestError) do
      authorize(context: { access_token: SECRET }, audit_context_keys: [:access_token])
    end

    refute_includes error.message, SECRET
  end

  test "unsupported audit value is not inspected into the exception message" do
    error = assert_raises(ActingFor::InvalidRequestError) do
      authorize(context: { payload: SensitiveObject.new }, audit_context_keys: [:payload])
    end

    refute_includes error.message, SECRET
    refute_includes error.message, "SensitiveObject"
  end

  test "audit persistence error keeps a safe public message and preserves the cause" do
    original = ActiveRecord::StatementInvalid.new("SQL failed with #{SECRET}")

    with_audit_create(->(*) { raise original }) do
      error = assert_raises(ActingFor::AuditPersistenceError) { authorize }

      assert_equal "Failed to persist audit event", error.message
      refute_includes error.message, SECRET
      assert_same original, error.cause
      assert_includes error.cause.message, SECRET
    end
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

  def with_audit_create(replacement)
    klass = ActingFor::AuditEvent
    singleton = klass.singleton_class
    owned = singleton.method_defined?(:create!, false)
    original = klass.method(:create!)
    singleton.define_method(:create!, replacement)
    yield
  ensure
    if owned
      singleton.define_method(:create!, original)
    else
      singleton.remove_method(:create!)
    end
  end
end

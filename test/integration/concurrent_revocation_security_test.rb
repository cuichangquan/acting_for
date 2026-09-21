require "test_helper"
require "securerandom"

class ConcurrentRevocationSecurityTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @agent = ActingFor::Agent.create!(
      identifier: "concurrent-revoke-#{SecureRandom.hex(6)}"
    )
    @principal = Principal.create!
    @delegation = ActingFor.delegate(
      agent: @agent,
      principal: @principal,
      action: :purchase,
      effect: :allow
    )
  end

  teardown do
    ActingFor::AuditEvent.where(agent_id: @agent.id).delete_all if @agent&.id
    ActingFor::Delegation.where(agent_id: @agent.id).delete_all if @agent&.id
    @agent&.delete
    @principal&.delete
  end

  test "concurrent revoke calls converge on the first persisted revocation" do
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    errors = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          results << ActingFor::Delegation.find(@delegation.id).revoke!.revoked_at
        end
      rescue StandardError => e
        errors << e
      end
    end

    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)

    raise errors.pop unless errors.empty?

    timestamps = 2.times.map { results.pop }
    stored = @delegation.reload.revoked_at

    assert_not_nil stored
    assert_equal [stored, stored], timestamps
    assert_equal :deny, authorize.status
  end

  private

  def authorize
    ActingFor.authorize(
      agent: @agent,
      principal: @principal,
      action: :purchase
    )
  end
end

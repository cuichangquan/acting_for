require "test_helper"

class DecisionTest < ActiveSupport::TestCase
  test "allow exposes the allow public behavior" do
    decision = ActingFor::Decision.new(:allow)

    assert_equal :allow, decision.status
    assert_predicate decision, :allowed?
    refute_predicate decision, :denied?
    refute_predicate decision, :approval_required?
  end

  test "deny exposes the deny public behavior" do
    decision = ActingFor::Decision.new(:deny)

    assert_equal :deny, decision.status
    refute_predicate decision, :allowed?
    assert_predicate decision, :denied?
    refute_predicate decision, :approval_required?
  end

  test "require approval is not allow" do
    decision = ActingFor::Decision.new(:require_approval)

    assert_equal :require_approval, decision.status
    refute_predicate decision, :allowed?
    refute_predicate decision, :denied?
    assert_predicate decision, :approval_required?
  end

  test "decision is frozen after initialization" do
    assert_predicate ActingFor::Decision.new(:allow), :frozen?
  end

  test "invalid status raises argument error" do
    assert_raises(ArgumentError) { ActingFor::Decision.new(:unknown) }
  end
end

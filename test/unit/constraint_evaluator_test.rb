require "test_helper"

class ConstraintEvaluatorTest < ActiveSupport::TestCase
  test "empty constraints match" do
    assert evaluate([], {})
  end

  test "single eq constraint passes and fails without coercion" do
    constraint = canonical_constraint("amount", "eq", 100)

    assert evaluate([constraint], { amount: 100 })
    refute evaluate([constraint], { amount: 101 })
    refute evaluate([constraint], { amount: "100" })
  end

  test "multiple constraints use AND semantics" do
    constraints = [
      canonical_constraint("amount", "lte", 100),
      canonical_constraint("currency", "eq", "JPY")
    ]

    assert evaluate(constraints, { amount: 100, currency: "JPY" })
    refute evaluate(constraints, { amount: 101, currency: "JPY" })
    refute evaluate(constraints, { amount: 100, currency: "USD" })
  end

  test "integer comparison operators honor boundary values" do
    assert evaluate([canonical_constraint("amount", "lt", 101)], { amount: 100 })
    assert evaluate([canonical_constraint("amount", "lte", 100)], { amount: 100 })
    assert evaluate([canonical_constraint("amount", "gt", 99)], { amount: 100 })
    assert evaluate([canonical_constraint("amount", "gte", 100)], { amount: 100 })

    refute evaluate([canonical_constraint("amount", "lt", 100)], { amount: 100 })
    refute evaluate([canonical_constraint("amount", "gt", 100)], { amount: 100 })
  end

  test "in uses strict scalar types" do
    constraint = canonical_constraint("amount", "in", [100, "200"])

    assert evaluate([constraint], { amount: 100 })
    assert evaluate([constraint], { amount: "200" })
    refute evaluate([constraint], { amount: "100" })
  end

  test "boolean equality uses strict boolean values" do
    constraint = canonical_constraint("confirmed", "eq", true)

    assert evaluate([constraint], { confirmed: true })
    refute evaluate([constraint], { confirmed: 1 })
  end

  test "missing or nil context field does not match" do
    constraint = canonical_constraint("amount", "eq", 100)

    refute evaluate([constraint], {})
    refute evaluate([constraint], { amount: nil })
  end

  test "constraint field matches only an exact top level symbol key" do
    constraint = canonical_constraint("amount", "eq", 100)

    assert evaluate([constraint], { amount: 100 })
    refute evaluate([constraint], { "amount" => 100 })
  end

  test "nested path is not interpreted" do
    constraint = canonical_constraint("order.amount", "eq", 100)

    refute evaluate([constraint], { order: { amount: 100 } })
    assert evaluate([constraint], { :"order.amount" => 100 })
  end

  test "invalid constraint fails closed" do
    extra_key = canonical_constraint("amount", "eq", 100).merge("extra" => true)
    symbol_keys = { field: "amount", operator: "eq", value: 100 }
    unknown_operator = canonical_constraint("amount", "between", 100)

    refute evaluate([extra_key], { amount: 100 })
    refute evaluate([symbol_keys], { amount: 100 })
    refute evaluate([unknown_operator], { amount: 100 })
  end

  test "invalid constraints or context container fails closed" do
    refute evaluate(nil, {})
    refute evaluate([], nil)
  end

  private

  def evaluate(constraints, context)
    ActingFor::Internal::ConstraintEvaluator.call(constraints: constraints, context: context)
  end

  def canonical_constraint(field, operator, value)
    { "field" => field, "operator" => operator, "value" => value }
  end
end

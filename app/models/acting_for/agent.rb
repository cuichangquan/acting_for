module ActingFor
  class Agent < ApplicationRecord
    has_many :delegations,
             class_name: "ActingFor::Delegation",
             dependent: :restrict_with_exception

    validates :identifier, uniqueness: { case_sensitive: true }
    validate :identifier_format
    validate :name_format

    private

    def identifier_format
      value = read_attribute_before_type_cast(:identifier)
      return if value.is_a?(String) && value.length.between?(1, 255) && !value.match?(/[[:space:]]/)

      errors.add(:identifier, "must be a String of 1..255 characters without whitespace")
    end

    def name_format
      value = read_attribute_before_type_cast(:name)
      return if value.nil?

      return if value.is_a?(String) && value.length.between?(1, 255) && !value.blank?

      errors.add(:name, "must be a nonblank String of 1..255 characters")
    end
  end
end

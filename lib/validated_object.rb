# frozen_string_literal: true

require 'active_model'
require 'validated_object/version'
require 'validated_object/simplified_api'

module ValidatedObject
  # @abstract Subclass and add `attr_accessor` and validations
  #   to create custom validating objects.
  #
  # Uses {http://api.rubyonrails.org/classes/ActiveModel/Validations/ClassMethods.html#method-i-validates ActiveModel::Validations}
  # to create self-validating Plain Old Ruby objects. This is especially
  # useful when importing data from one system into another. This class also
  # creates very readable error messages.
  #
  # @example Writing a self-validating object
  #   class Dog < ValidatedObject::Base
  #     attr_accessor :name, :birthday
  #
  #     validates :name, presence: true
  #     validates :birthday, type: Date, allow_nil: true
  #   end
  #
  # @example Instantiating and automatically validating
  #   # The dog1 instance validates itself at the end of instantiation.
  #   # Here, it succeeds and so doesn't raise an exception.
  #   dog1 = Dog.new name: 'Spot'
  #
  #   # We can also explicitly test for validity
  #   dog1.valid?  # => true
  #
  #   dog1.birthday = Date.new(2015, 1, 23)
  #   dog1.valid?  # => true
  #
  # @example Making an instance invalid
  #   dog1.birthday = '2015-01-23'
  #   dog1.valid?  # => false
  #   dog1.check_validations!  # => ArgumentError: Birthday is class String, not Date
  #
  # @see ValidatedObject::Base::TypeValidator
  # @see http://yehudakatz.com/2010/01/10/activemodel-make-any-ruby-object-feel-like-activerecord/ ActiveModel: Make Any Ruby Object Feel Like ActiveRecord, Yehuda Katz
  # @see http://www.rubyinside.com/rails-3-0s-activemodel-how-to-give-ruby-classes-some-activerecord-magic-2937.html Rails 3.0′s ActiveModel: How To Give Ruby Classes Some ActiveRecord Magic, Peter Cooper
  class Base
    include ActiveModel::Validations
    include SimplifiedApi

    EMPTY_HASH = {}

    # A private class definition, not intended to
    # be used directly. Implements a pseudo-boolean class
    # enabling validations like this:
    #
    #   validates :enabled, type: Boolean
    class Boolean
    end

    # Instantiate and validate a new object.
    # @example
    #   maru = Dog.new(birthday: Date.today, name: 'Maru')
    #
    # @raise [ArgumentError] if the object is not valid at the
    #   end of initialization or `attributes` is not a Hash.
    def initialize(attributes = EMPTY_HASH)
      set_instance_variables from_hash: attributes
      check_validations!
    end

    def validated_attr(attribute_name, **validation_options)
      attr_reader attribute_name

      validates attribute_name, validation_options
    end

    # Run any validations and raise an error if invalid.
    #
    # @raise [ArgumentError] if any validations fail.
    # @return [ValidatedObject::Base] the receiver
    def check_validations!
      raise ArgumentError, errors.full_messages.join('; ') if invalid?

      self
    end

    # A custom validator which ensures an object is an instance of a class
    # or a subclass. It supports a pseudo-boolean class for convenient
    # validation. (Ruby doesn't have a built-in Boolean.)
    #
    # Automatically used in a `type` validation:
    #
    # @example Ensure that weight is a number
    #   class Dog < ValidatedObject::Base
    #     attr_accessor :weight, :neutered
    #     validates :weight, type: Numeric  # Typed and required
    #     validates :neutered, type: Boolean, allow_nil: true  # Typed but optional
    #   end
    class TypeValidator < ActiveModel::EachValidator
      # @return [nil]
      def validate_each(record, attribute, value)
        validation_options = options
        expected_class = validation_options[:with]

        # Support type: Array, element_type: ElementType
        if expected_class == Array && validation_options[:element_type]
          return save_error(record, attribute, value, validation_options) unless value.is_a?(Array)

          element_type = validation_options[:element_type]
          unless value.all? { |el| el.is_a?(element_type) }
            record.errors.add attribute, validation_options[:message] || "contains non-#{element_type} elements"
          end
          return
        end

        return if pseudo_boolean?(expected_class, value) ||
                  expected_class?(expected_class, value)

        save_error(record, attribute, value, validation_options)
      end

      private

      def pseudo_boolean?(expected_class, value)
        expected_class == Boolean && boolean?(value)
      end

      def expected_class?(expected_class, value)
        value.is_a?(expected_class)
      end

      def boolean?(value)
        value.is_a?(TrueClass) || value.is_a?(FalseClass)
      end

      def save_error(record, attribute, value, validation_options)
        record.errors.add attribute,
                          validation_options[:message] || "is a #{value.class}, not a #{validation_options[:with]}"
      end
    end

    # Register the TypeValidator with ActiveModel so `type:` validation option works
    unless ActiveModel::Validations.const_defined?(:TypeValidator)
      ActiveModel::Validations.const_set(:TypeValidator, TypeValidator)
    end

    # Allow 'validated' as a synonym for 'validates'
    def self.validated(*args, **kwargs, &block)
      validates(*args, **kwargs, &block)
    end

    private

    def set_instance_variables(from_hash:)
      raise TypeError, "#{from_hash} is not a hash" unless from_hash.is_a?(Hash)

      from_hash.each do |variable_name, variable_value|
        # Test for the attribute reader
        send variable_name.to_sym

        # Set value in a way that succeeds even if attr is read-only
        instance_variable_set "@#{variable_name}".to_sym, variable_value
      end
    end
  end
end

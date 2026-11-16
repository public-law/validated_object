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

    EMPTY_HASH = {}.freeze

    # A private class definition, not intended to
    # be used directly. Implements a pseudo-boolean class
    # enabling validations like this:
    #
    #   validates :enabled, type: Boolean
    class Boolean
    end

    # A private class definition for union types.
    # Stores multiple allowed types for validation.
    # Created via ValidatedObject::Base.union(*types)
    #
    # @example
    #   validates :id, type: union(String, Integer)
    #   validates :data, type: union(Hash, [Hash])
    class Union
      attr_reader :types

      def initialize(*types)
        @types = types
      end
    end

    # Instantiate and validate a new object.
    # @example
    #   maru = Dog.new(birthday: Date.today, name: 'Maru')
    #
    # @raise [ArgumentError] if the object is not valid at the
    #   end of initialization or `attributes` is not a Hash.
    def initialize(attributes = EMPTY_HASH)
      assign_declared_attributes attributes
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
      return self if !defined?(@errors) && self.class.fast_valid?(self)
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

        # Support union types
        if expected_class.is_a?(Union)
          return if validate_union_type(record, attribute, value, expected_class, validation_options)

          save_union_error(record, attribute, value, expected_class, validation_options)
          return
        end

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

      FAST_PATH_OPTIONS = %i[with element_type allow_nil message].freeze

      # @return [Boolean] whether {#acceptable?} fully decides this validation
      def fast_path?
        options.each_key.all? { |key| FAST_PATH_OPTIONS.include?(key) }
      end

      # The allocation-free equivalent of {#validate_each} reporting success.
      # @return [Boolean]
      def acceptable?(value)
        return true if value.nil? && options[:allow_nil]

        acceptable_type?(value, options[:with])
      end

      private

      def acceptable_type?(value, expected_class)
        return validate_union_type(nil, nil, value, expected_class, options) if expected_class.is_a?(Union)

        element_type = options[:element_type]
        if expected_class == Array && element_type
          return value.is_a?(Array) && validate_array_element_type(value, element_type)
        end

        pseudo_boolean?(expected_class, value) || expected_class?(expected_class, value)
      end

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

      def validate_union_type(_record, _attribute, value, union, _validation_options)
        union.types.any? do |type_spec|
          if type_spec.is_a?(Array) && type_spec.length == 1
            # Handle [ElementType] syntax within union
            validate_array_element_type(value, type_spec[0])
          elsif type_spec.is_a?(Class) || type_spec == Boolean
            # Handle class types (String, Integer, etc.) and pseudo-boolean
            pseudo_boolean?(type_spec, value) || expected_class?(type_spec, value)
          else
            # Handle literal values (symbols, strings, numbers, etc.)
            value == type_spec
          end
        end
      end

      def validate_array_element_type(value, element_type)
        return false unless value.is_a?(Array)

        value.all? { |el| el.is_a?(element_type) }
      end

      def save_union_error(record, attribute, value, union, validation_options)
        return if validation_options[:message]

        type_names = union.types.map do |type_spec|
          if type_spec.is_a?(Array) && type_spec.length == 1
            "Array of #{type_spec[0]}"
          elsif type_spec.is_a?(Class) || type_spec == Boolean
            type_spec.to_s
          else
            # For literal values like :active, show them as-is
            type_spec.inspect
          end
        end

        message = if type_names.length == 1
                    "is a #{value.class}, not one of #{type_names.first}"
                  else
                    "is a #{value.class}, not one of #{type_names.join(', ')}"
                  end

        record.errors.add attribute, message
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

    # Create a union type specification for validation
    # @param types [Array] The types that are allowed
    # @return [Union] A union type specification
    # @example
    #   validates :id, type: union(String, Integer)
    #   validates :data, type: union(Hash, [Hash])
    def self.union(*types)
      Union.new(*types)
    end

    # The allocation-free equivalent of a successful `validates_format_of`
    # with a literal `with:` Regexp.
    #
    # @api private
    class FormatCheck
      OPTIONS = %i[with allow_nil allow_blank message].freeze

      def self.from(validator)
        options = validator.options
        return nil unless options[:with].is_a?(Regexp) && options.each_key.all? { |key| OPTIONS.include?(key) }

        new(options[:with], allow_nil: options[:allow_nil], allow_blank: options[:allow_blank])
      end

      def initialize(regexp, allow_nil:, allow_blank:)
        @regexp = regexp
        @allow_nil = allow_nil
        @allow_blank = allow_blank
        freeze
      end

      def acceptable?(value)
        return true if value.nil? && @allow_nil
        return true if @allow_blank && value.blank?

        @regexp.match?(value.to_s)
      end
    end

    # Checks the receiver without ActiveModel's per-call allocations when
    # every validation is a plain `type:` check. A `false` result only means
    # the full ActiveModel run must decide, and build the error messages.
    #
    # @api private
    # @return [Boolean]
    def self.fast_valid?(record)
      plan = fast_path_plan
      return false unless plan

      plan.all? do |attribute, check|
        check.acceptable?(record.read_attribute_for_validation(attribute))
      end
    end

    # The instance variable for an attribute key, only when the key names a
    # public reader declared below {Base}. Anything else, such as `exit!`,
    # `errors` or `instance_eval`, is rejected without being called.
    #
    # @api private
    # @return [Symbol]
    # @raise [NoMethodError] if the key is not a declared attribute.
    def self.instance_variable_for(key)
      attribute_ivars[key] || register_attribute(key)
    end

    def self.fast_path_plan
      callbacks = _validate_callbacks
      return @fast_path_plan if callbacks.equal?(@fast_path_callbacks)

      @fast_path_plan = build_fast_path_plan(callbacks)
      @fast_path_callbacks = callbacks
      @fast_path_plan
    end

    def self.build_fast_path_plan(callbacks)
      return nil unless stock_validation_run?

      validators = callbacks.map(&:filter)
      checks = validators.map { |validator| fast_check_for(validator) }
      return nil unless checks.all?

      validators.zip(checks).flat_map do |validator, check|
        validator.attributes.map { |attribute| [attribute, check].freeze }
      end.freeze
    end

    def self.fast_check_for(validator)
      case validator
      when TypeValidator then validator if validator.fast_path?
      when ActiveModel::Validations::FormatValidator then FormatCheck.from(validator)
      end
    end

    def self.stock_validation_run?
      %i[valid? invalid? run_validations!].all? do |name|
        instance_method(name).owner.equal?(ActiveModel::Validations)
      end
    end

    def self.attribute_ivars
      @attribute_ivars ||= {}
    end

    def self.register_attribute(key)
      name = key.to_sym
      raise NoMethodError.new("undefined attribute '#{name}' for #{self}", name) unless attribute_reader?(name)

      attribute_ivars[key] = :"@#{name}"
    end

    def self.attribute_reader?(name)
      public_method_defined?(name) && !Base.ancestors.include?(instance_method(name).owner)
    end

    private_class_method :fast_path_plan, :build_fast_path_plan, :attribute_ivars,
                         :register_attribute, :attribute_reader?, :stock_validation_run?,
                         :fast_check_for

    private

    def assign_declared_attributes(attributes)
      raise TypeError, "#{attributes} is not a hash" unless attributes.is_a?(Hash)

      attributes.each do |key, value|
        instance_variable_set self.class.instance_variable_for(key), value
      end
    end
  end
end

# frozen_string_literal: true

require 'active_support/concern'

module ValidatedObject
  # Enable a simplified API for the common case of
  # read-only ValidatedObjects.
  module SimplifiedApi
    extend ActiveSupport::Concern

    class_methods do
      # Simply delegate to `attr_reader` and `validates`.
      def validated_attr(attribute, *options)
        attr_reader attribute

        validates attribute, *options
      end

      # Allow 'validated' as a synonym for 'validates'.
      def validated(*args, **kwargs, &block)
        validates(*args, **kwargs, &block)
      end

      def validates_attr(attribute, *options, **kwargs)
        attr_reader attribute

        if kwargs[:type]
          type_val = kwargs.delete(:type)
          element_type = kwargs.delete(:element_type)

          # Handle Union types - pass them through directly
          if type_val.is_a?(ValidatedObject::Base::Union)
            opts = { type: { with: type_val } }
            validates attribute, opts.merge(kwargs)
          # Parse Array[ElementType] syntax
          elsif type_val.is_a?(Array) && type_val.length == 1 && type_val[0].is_a?(Class)
            # This handles Array[Comment] syntax
            element_type = type_val[0]
            type_val = Array
            opts = { type: { with: type_val } }
            opts[:type][:element_type] = element_type if element_type
            validates attribute, opts.merge(kwargs)
          else
            opts = { type: { with: type_val } }
            opts[:type][:element_type] = element_type if element_type
            validates attribute, opts.merge(kwargs)
          end
        else
          validates attribute, *options, **kwargs
        end
      end
    end
  end
end

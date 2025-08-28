# frozen_string_literal: true

require 'spec_helper'
require 'validated_object'

#
# I needed to create actual classes for these specs to work.
# Therefore I namespaced them with Spec.
#
class SpecUnionComment; end

describe 'ValidatedObject Union Types' do
  context 'when using union types' do
    let(:multi_type_class) do
      Class.new(ValidatedObject::Base) do
        attr_accessor :id, :status, :data
        
        validates :id, type: union(String, Integer)
        validates :status, type: union(:active, :inactive, :pending)
        validates :data, type: union(Hash, [Hash]), allow_nil: true
      end
    end

    it 'accepts values matching first union type (String)' do
      obj = multi_type_class.new(id: 'abc123', status: :active, data: { key: 'value' })
      expect(obj).to be_valid
    end

    it 'accepts values matching second union type (Integer)' do
      obj = multi_type_class.new(id: 42, status: :inactive, data: nil)
      expect(obj).to be_valid
    end

    it 'accepts values matching array element type in union' do
      obj = multi_type_class.new(id: 'test', status: :pending, data: [{ a: 1 }, { b: 2 }])
      expect(obj).to be_valid
    end

    it 'rejects values not matching any union type' do
      expect do
        multi_type_class.new(id: 3.14, status: :active, data: {})
      end.to raise_error(ArgumentError, /is a Float, not one of String or Integer/)
    end

    it 'rejects invalid symbol values in union' do
      expect do
        multi_type_class.new(id: 'test', status: :invalid, data: {})
      end.to raise_error(ArgumentError, /is a Symbol.*not one of.*active.*inactive.*pending/)
    end

    it 'works with validates_attr syntax' do
      union_attr_class = Class.new(ValidatedObject::Base) do
        validates_attr :mixed, type: union(String, Integer, [String])
      end

      expect(union_attr_class.new(mixed: 'text')).to be_valid
      expect(union_attr_class.new(mixed: 42)).to be_valid
      expect(union_attr_class.new(mixed: %w[a b c])).to be_valid
      
      expect do
        union_attr_class.new(mixed: 3.14)
      end.to raise_error(ArgumentError, /is a Float.*not one of.*String.*Integer.*Array of String/)
    end

    it 'handles complex union with multiple array types' do
      complex_class = Class.new(ValidatedObject::Base) do
        attr_accessor :flexible
        validates :flexible, type: union(String, Integer, [String], [Hash])
      end

      expect(complex_class.new(flexible: 'text')).to be_valid
      expect(complex_class.new(flexible: 123)).to be_valid
      expect(complex_class.new(flexible: %w[a b])).to be_valid
      expect(complex_class.new(flexible: [{ a: 1 }, { b: 2 }])).to be_valid

      expect do
        complex_class.new(flexible: [1, 2, 3])
      end.to raise_error(ArgumentError, /Array.*contains non-String elements/)
    end

    it 'works with single type union (equivalent to regular type validation)' do
      single_union_class = Class.new(ValidatedObject::Base) do
        attr_accessor :name
        validates :name, type: union(String)
      end

      expect(single_union_class.new(name: 'test')).to be_valid
      expect do
        single_union_class.new(name: 123)
      end.to raise_error(ArgumentError, /is a Integer, not one of String/)
    end
  end
end
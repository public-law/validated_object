# frozen_string_literal: true

require 'spec_helper'
require 'validated_object'

#
# I needed to create actual classes for these specs to work.
# Therefore I namespaced them with Spec.
#
class SpecUnionComment; end

class SpecMultiType < ValidatedObject::Base
  attr_accessor :id, :status, :data

  validates :id, type: union(String, Integer)
  validates :status, type: union(:active, :inactive, :pending)
  validates :data, type: union(Hash, [Hash]), allow_nil: true
end

class SpecUnionAttr < ValidatedObject::Base
  validates_attr :mixed, type: union(String, Integer, [String])
end

class SpecComplexUnion < ValidatedObject::Base
  attr_accessor :flexible

  validates :flexible, type: union(String, Integer, [String], [Hash])
end

class SpecSingleUnion < ValidatedObject::Base
  attr_accessor :name

  validates :name, type: union(String)
end

describe 'ValidatedObject Union Types' do
  context 'when using union types' do
    it 'accepts values matching first union type (String)' do
      obj = SpecMultiType.new(id: 'abc123', status: :active, data: { key: 'value' })
      expect(obj).to be_valid
    end

    it 'accepts values matching second union type (Integer)' do
      obj = SpecMultiType.new(id: 42, status: :inactive, data: nil)
      expect(obj).to be_valid
    end

    it 'accepts values matching array element type in union' do
      obj = SpecMultiType.new(id: 'test', status: :pending, data: [{ a: 1 }, { b: 2 }])
      expect(obj).to be_valid
    end

    it 'rejects values not matching any union type' do
      expect do
        SpecMultiType.new(id: 3.14, status: :active, data: {})
      end.to raise_error(ArgumentError, /is a Float, not one of String, Integer/)
    end

    it 'rejects invalid symbol values in union' do
      expect do
        SpecMultiType.new(id: 'test', status: :invalid, data: {})
      end.to raise_error(ArgumentError, /is a Symbol.*not one of.*active.*inactive.*pending/)
    end

    it 'works with validates_attr syntax' do
      expect(SpecUnionAttr.new(mixed: 'text')).to be_valid
      expect(SpecUnionAttr.new(mixed: 42)).to be_valid
      expect(SpecUnionAttr.new(mixed: %w[a b c])).to be_valid

      expect do
        SpecUnionAttr.new(mixed: 3.14)
      end.to raise_error(ArgumentError, /is a Float.*not one of.*String.*Integer.*Array of String/)
    end

    it 'handles complex union with multiple array types' do
      expect(SpecComplexUnion.new(flexible: 'text')).to be_valid
      expect(SpecComplexUnion.new(flexible: 123)).to be_valid
      expect(SpecComplexUnion.new(flexible: %w[a b])).to be_valid
      expect(SpecComplexUnion.new(flexible: [{ a: 1 }, { b: 2 }])).to be_valid

      expect do
        SpecComplexUnion.new(flexible: [1, 2, 3])
      end.to raise_error(ArgumentError, /is a Array, not one of String, Integer, Array of String, Array of Hash/)
    end

    it 'works with single type union (equivalent to regular type validation)' do
      expect(SpecSingleUnion.new(name: 'test')).to be_valid
      expect do
        SpecSingleUnion.new(name: 123)
      end.to raise_error(ArgumentError, /is a Integer, not one of String/)
    end
  end
end

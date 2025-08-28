# frozen_string_literal: true

require 'spec_helper'
require 'validated_object'

describe ValidatedObject do
  let(:apple) do
    Class.new(ValidatedObject::Base) do
      attr_accessor :diameter

      validates :diameter, type: Float
    end
  end

  let(:immutable_apple) do
    Class.new(ValidatedObject::Base) do
      attr_reader :diameter

      validates :diameter, type: Float
    end
  end

  let(:apple_subclass) do
    Class.new(apple) do
    end
  end

  it 'has a version number' do
    expect(ValidatedObject::VERSION).not_to be_nil
  end

  it 'can be referenced' do
    expect(ValidatedObject::Base).not_to be_nil
  end

  it 'throws a TypeError if non-hash is given' do
    expect do
      apple.new(5)
    end.to raise_error(TypeError)
  end

  it 'supports readonly attributes' do
    apple = immutable_apple.new(diameter: 4.0)
    expect(apple.diameter).to eq 4.0
  end

  it 'raises an error when trying to set a readonly attribute' do
    apple = immutable_apple.new(diameter: 4.0)
    expect { apple.diameter = 5.0 }.to raise_error(NoMethodError)
  end

  it 'raises an error on unknown attribute' do
    expect do
      apple.new(diameter: 4.0, name: 'Bert')
    end.to raise_error(NoMethodError)
  end

  context 'when using the TypeValidator' do
    it 'verifies a valid type' do
      small_apple = apple.new(diameter: 2.0)
      expect(small_apple).to be_valid
    end

    it 'rejects an invalid type' do
      expect do
        apple.new diameter: '2'
      end.to raise_error(ArgumentError)
    end

    it 'can verify a subclass' do
      small_apple = apple_subclass.new(diameter: 5.5)

      expect(small_apple).to be_valid
    end

    it 'can verify a subclass with a new attribute' do
      apple_subclass = Class.new(apple) do
        validated_attr :color, type: String
      end

      red_apple = apple_subclass.new(diameter: 5.5, color: 'red')
      expect(red_apple).to be_valid
    end

    it 'handles Boolean types' do
      boolean_apple = Class.new(ValidatedObject::Base) do
        attr_accessor :rotten

        # Outside of specs, in normal usage, you would use:
        #   validates :rotten, type: Boolean
        validates :rotten, type: ValidatedObject::Base::Boolean
      end

      expect(boolean_apple.new(rotten: true)).to be_valid
    end

    it 'rejects invalid boolean types' do
      boolean_apple = Class.new(ValidatedObject::Base) do
        attr_accessor :rotten

        # Outside of specs, in normal usage, you would use:
        #   validates :rotten, type: Boolean
        validates :rotten, type: ValidatedObject::Base::Boolean
      end

      expect { boolean_apple.new(rotten: 1) }.to raise_error(ArgumentError)
    end

    it "allows 'validated' as a synonym for 'validates'" do
      synonym_apple = Class.new(ValidatedObject::Base) do
        attr_accessor :diameter

        validated :diameter, type: Float
      end

      expect(synonym_apple.new(diameter: 1.0)).to be_valid
    end

    it "allows 'validated' as a synonym for 'validates', rejecting invalid types" do
      synonym_apple = Class.new(ValidatedObject::Base) do
        attr_accessor :diameter

        validated :diameter, type: Float
      end

      expect { synonym_apple.new(diameter: 'bad') }.to raise_error(ArgumentError)
    end

    context 'when an Array is defined with the verbose syntax' do
      #
      # I needed to create actual classes for these specs to work.
      # Therefore I namespaced them with Spec.
      #
      class SpecComment; end # rubocop:disable Lint/LeakyConstantDeclaration

      class SpecPost < ValidatedObject::Base # rubocop:disable Lint/LeakyConstantDeclaration
        validates_attr :comments, type: Array, element_type: SpecComment, allow_nil: true
        validates_attr :tags,     type: Array, element_type: String, allow_nil: true
      end

      it 'accepts an array of correct element type (element_type: syntax) - 1' do
        c1 = SpecComment.new
        c2 = SpecComment.new
        expect(SpecPost.new(comments: [c1, c2])).to be_valid
      end

      it 'rejects an array with wrong element type (element_type: syntax) - 1' do
        expect do
          SpecPost.new(comments: [SpecComment.new, 'bad'])
        end.to raise_error(ArgumentError, /contains non-SpecComment elements/)
      end

      it 'accepts an array of correct element type (element_type: syntax) - 2' do
        expect(SpecPost.new(tags: %w[foo bar])).to be_valid
      end

      it 'rejects an array with wrong element type (element_type: syntax) - 2' do
        expect do
          SpecPost.new(tags: ['foo', 123])
        end.to raise_error(ArgumentError, /contains non-String elements/)
      end

      it 'rejects non-array values when element_type is specified' do
        expect do
          SpecPost.new(comments: 'not an array')
        end.to raise_error(ArgumentError, /is a String, not a Array/)
      end

      it 'allows an Array to be nil if allow_nil: true' do
        expect(SpecPost.new(comments: nil, tags: nil)).to be_valid
      end
    end

    context 'when an Array is defined with the streamlined syntax' do
      let(:streamlined_post) do
        Class.new(ValidatedObject::Base) do
          validates_attr :comments, type: [SpecComment], allow_nil: true
          validates_attr :id,       type: Integer
        end
      end

      it 'supports the streamlined syntax' do
        post = streamlined_post.new(comments: [SpecComment.new, SpecComment.new], id: 1)

        expect(post).to be_valid
      end

      it 'assigns an integer attribute correctly' do
        post = streamlined_post.new(comments: [SpecComment.new, SpecComment.new], id: 1)
        expect(post.id).to eq 1
      end

      it 'assigns comments as an array' do
        post = streamlined_post.new(comments: [SpecComment.new, SpecComment.new], id: 1)
        expect(post.comments).to be_an(Array)
      end

      it 'preserves comment array length' do
        post = streamlined_post.new(comments: [SpecComment.new, SpecComment.new], id: 1)
        expect(post.comments.length).to eq 2
      end

      it 'preserves comment array element types' do
        post = streamlined_post.new(comments: [SpecComment.new, SpecComment.new], id: 1)
        expect(post.comments.first).to be_a(SpecComment)
      end
    end
  end
end

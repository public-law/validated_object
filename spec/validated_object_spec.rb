# frozen_string_literal: true

require 'spec_helper'

describe ValidatedObject do
  class Apple < ValidatedObject::Base
    attr_accessor :diameter

    validates :diameter, type: Float
  end

  it 'has a version number' do
    expect(ValidatedObject::VERSION).not_to be nil
  end

  it 'can be referenced' do
    expect(ValidatedObject::Base).not_to be nil
  end

  it 'throws a TypeError if non-hash is given' do
    expect do
      Apple.new(5)
    end.to raise_error(TypeError)
  end

  it 'supports readonly attributes' do
    class ImmutableApple < ValidatedObject::Base
      attr_reader :diameter

      validates :diameter, type: Float
    end

    apple = ImmutableApple.new(diameter: 4.0)
    expect(apple.diameter).to eq 4.0
    expect { apple.diameter = 5.0 }.to raise_error(NoMethodError)
  end

  it 'supports simplified readonly attributes' do
    class ImmutableApple < ValidatedObject::Base
      validated_attr :diameter, type: Float
    end

    apple = ImmutableApple.new(diameter: 4.0)
    expect(apple.diameter).to eq 4.0
    expect { apple.diameter = 5.0 }.to raise_error(NoMethodError)
  end

  it 'raises error on unknown attribute' do
    expect do
      Apple.new(diameter: 4.0, name: 'Bert')
    end.to raise_error(NoMethodError)
  end

  context 'TypeValidator' do
    it 'verifies a valid type' do
      small_apple = Apple.new(diameter: 2.0)
      expect(small_apple).to be_valid
    end

    it 'rejects an invalid type' do
      expect do
        Apple.new diameter: '2'
      end.to raise_error(ArgumentError)
    end

    it 'can verify a subclass' do
      class Apple2 < Apple
      end

      small_apple = Apple2.new(diameter: 5.5)
      expect(small_apple).to be_valid
    end

    it 'can verify a subclass with a new attribute' do
      class Apple2 < Apple
        validated_attr :color, type: String
      end

      red_apple = Apple2.new(diameter: 5.5, color: 'red')
      expect(red_apple).to be_valid
    end

    it 'handles Boolean types' do
      class Apple3 < ValidatedObject::Base
        attr_accessor :rotten

        validates :rotten, type: Boolean
      end

      rotten_apple = Apple3.new rotten: true
      expect(rotten_apple).to be_valid
    end

    it 'rejects invalid boolean types' do
      class Apple4 < ValidatedObject::Base
        attr_accessor :rotten

        validates :rotten, type: Boolean
      end

      expect { Apple4.new rotten: 1 }.to raise_error(ArgumentError)
    end

    it "allows 'validated' as a synonym for 'validates'" do
      class SynonymApple < ValidatedObject::Base
        attr_accessor :diameter

        validated :diameter, type: Float
      end
      apple = SynonymApple.new(diameter: 1.0)
      expect(apple).to be_valid
      expect { SynonymApple.new(diameter: 'bad') }.to raise_error(ArgumentError)
    end
  end

  context 'Array element type validation' do
    class Comment; end

    class Post < ValidatedObject::Base
      validates_attr :comments, type: Array, element_type: Comment, allow_nil: true
      validates_attr :tags,     type: Array, element_type: String,  allow_nil: true
    end

    it 'accepts an array of correct element type (element_type: syntax)' do
      c1 = Comment.new
      c2 = Comment.new
      post = Post.new(comments: [c1, c2])
      expect(post).to be_valid
    end

    it 'rejects an array with wrong element type (element_type: syntax)' do
      expect do
        Post.new(comments: [Comment.new, 'bad'])
      end.to raise_error(ArgumentError, /contains non-Comment elements/)
    end

    it 'accepts an array of correct element type (element_type: syntax)' do
      post = Post.new(tags: %w[foo bar])
      expect(post).to be_valid
    end

    it 'rejects an array with wrong element type (element_type: syntax)' do
      expect do
        Post.new(tags: ['foo', 123])
      end.to raise_error(ArgumentError, /contains non-String elements/)
    end

    it 'rejects non-array values when element_type is specified' do
      expect do
        Post.new(comments: 'not an array')
      end.to raise_error(ArgumentError, /is a String, not a Array/)
    end

    it 'allows an Array to be nil if allow_nil: true' do
      post = Post.new(comments: nil, tags: nil)
      expect(post).to be_valid
    end

    it 'supports a streamlined syntax for element_type' do
      class Post2 < ValidatedObject::Base
        validates_attr :comments, type: Array[Comment], allow_nil: true
      end

      post = Post2.new(comments: [Comment.new, Comment.new])
      expect(post).to be_valid
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

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

    context 'when an Array is defined with the verbose syntax' do
      class Comment; end

      class Post < ValidatedObject::Base
        validates_attr :comments, type: Array, element_type: Comment, allow_nil: true
        validates_attr :tags,     type: Array, element_type: String,  allow_nil: true
      end

      it 'accepts an array of correct element type (element_type: syntax) - 1' do
        c1 = Comment.new
        c2 = Comment.new
        post = Post.new(comments: [c1, c2])
        expect(post).to be_valid
      end

      it 'rejects an array with wrong element type (element_type: syntax) - 1' do
        expect do
          Post.new(comments: [Comment.new, 'bad'])
        end.to raise_error(ArgumentError, /contains non-Comment elements/)
      end

      it 'accepts an array of correct element type (element_type: syntax) - 2' do
        post = Post.new(tags: %w[foo bar])
        expect(post).to be_valid
      end

      it 'rejects an array with wrong element type (element_type: syntax) - 2' do
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
    end

    context 'when an Array is defined with the streamlined syntax' do
      let(:streamlined_post) do
        Class.new(ValidatedObject::Base) do
          validates_attr :comments, type: [Comment], allow_nil: true
          validates_attr :id,       type: Integer
        end
      end

      it 'supports the streamlined syntax' do
        post = streamlined_post.new(comments: [Comment.new, Comment.new], id: 1)

        expect(post).to be_valid
      end

      it 'assigns id correctly' do
        post = streamlined_post.new(comments: [Comment.new, Comment.new], id: 1)
        expect(post.id).to eq 1
      end

      it 'assigns comments as an array' do
        post = streamlined_post.new(comments: [Comment.new, Comment.new], id: 1)
        expect(post.comments).to be_an(Array)
      end

      it 'preserves comment count' do
        post = streamlined_post.new(comments: [Comment.new, Comment.new], id: 1)
        expect(post.comments.length).to eq 2
      end

      it 'preserves comment types' do
        post = streamlined_post.new(comments: [Comment.new, Comment.new], id: 1)
        expect(post.comments.first).to be_a(Comment)
      end
    end
  end
end

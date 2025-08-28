[![Gem Version](https://badge.fury.io/rb/validated_object.svg)](https://badge.fury.io/rb/validated_object) 
# ValidatedObject

`Plain Old Ruby` + `Rails Validations` = **self-checking Ruby objects**.

## Example: A `Person` class that ensures its `name` isn't blank (nil or empty string):

```ruby
class Person < ValidatedObject::Base
  attr_reader :name
  validates :name, presence: true
end

# Instantiating it runs the validations.
me  = Person.new(name: 'Robert')
you = Person.new(name: '')     # => ArgumentError: "Name can't be blank"
```

Note how Person's two lines of code are nothing new: `attr_reader` is standard Ruby. [`validates`](https://guides.rubyonrails.org/active_record_validations.html) is standard Rails. I use classes like these as Data Transfer Objects at my system boundaries.


## Goals

* Very readable error messages
* Clean, minimal syntax

This is a small layer around
[ActiveModel::Validations](http://api.rubyonrails.org/classes/ActiveModel/Validations/ClassMethods.html#method-i-validates). (About 25 lines of code.) So if you know how to use [Rails Validations](https://guides.rubyonrails.org/active_record_validations.html), you're good to go. I wrote this to help with CSV data imports and [website structured data](https://github.com/public-law/schema-dot-org).


## Usage


### Writing a self-validating object

All of the [ActiveModel::Validations](http://api.rubyonrails.org/classes/ActiveModel/Validations/ClassMethods.html#method-i-validates) are available, plus a new one, `TypeValidator`.

```ruby
class Dog < ValidatedObject::Base
  # Plain old Ruby
  attr_accessor :name, :birthday

  # Plain old Rails
  validates :name, presence: true
  
  # A new type-validation if you'd like to use it
  validates :birthday, type: Date, allow_nil: true  # Strongly typed but optional
end
```

Alternatively, we could make it immutable with Ruby's [attr_reader](https://bootrails.com/blog/ruby-attr-accessor-attr-writer-attr-reader/#2-attr_reader-attr_writer--attr_accessor):

```ruby
class ImmutableDog < ValidatedObject::Base
  attr_reader :name, :birthday

  validates :name, presence: true
  validates :birthday, type: Date, allow_nil: true
end
```

And again, that `ImmutableDog` consists of one line of plain Ruby and two lines of standard Rails validations.

### `attr_reader` followed by `validates` is such a common pattern that there's a DSL which wraps them up into one call: `validates_attr`.

Here's the immutable version of `Dog` re-written with the new, simplified DSL:

```ruby
class ImmutableDog < ValidatedObject::Base
  validates_attr :name, presence: true
  validates_attr :birthday, type: Date, allow_nil: true 
end
```

### About that `type:` check

The included `TypeValidator` is what enables `type: Date`, above. All classes can be checked, as well as a pseudo-class `Boolean`. E.g.:

```ruby
#...
validates :premium_membership, type: Boolean
#...
```


### Array element type validation

You can validate that an attribute is an array of a specific type using array syntax:

```ruby
# Validate that names is an array of String objects.
validates_attr :names, type: [String]
```

If the array contains any elements that are not of the specified type, validation will fail with a clear error message.


### Instantiating and automatically validating

```ruby
# This Dog instance validates itself at the end of instantiation.
spot = Dog.new(name: 'Spot')
```

```ruby
# We can also explicitly test for validity because all of
# ActiveModel::Validations is available.
spot.valid?  # => true

spot.birthday = Date.new(2015, 1, 23)
spot.valid?  # => true
```

### Good error messages

Any of the standard Validations methods can be
used to test an instance, plus the custom `check_validations!` convenience method:

```ruby
spot.birthday = '2015-01-23'
spot.valid?  # => false
spot.check_validations!  # => ArgumentError: Birthday is a String, not a Date
```

Note the clear, explicit error message. These are great when reading a log
file following a data import. It describes all the invalid conditions. Let's 
test it by making another attribute invalid:

```ruby
spot.name = nil
spot.check_validations!  # => ArgumentError: Name can't be blank; Birthday is a String, not a Date
```


### Use in parsing data

I often use a validated object in a loop to import data, e.g.:

```ruby
# Import a CSV file of dogs
dogs = []
csv.next_row do |row|
  begin
    dogs << Dog.new(name: row.name)
  rescue ArgumentError => e
    logger.warn(e)
  end
end
```

The result is that `dogs` is an array of guaranteed valid Dog objects. And the
error log lists unparseable rows with good info for tracking down problems in
the data.

### Use in code generation

My [Schema.org structured data gem](https://github.com/public-law/schema-dot-org) uses ValidatedObjects to recursively create well formed HTML / JSON-LD. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'validated_object'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install validated_object



## Development

(TODO: Verify these instructions.) After checking out the repo, run `bin/setup`
to install dependencies. Then, run `rake spec` to run the tests. You can also
run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

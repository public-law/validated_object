[![Gem Version](https://badge.fury.io/rb/validated_object.svg)](https://badge.fury.io/rb/validated_object) 
# ValidatedObject

**Self-validating Plain Old Ruby Objects** using Rails validations.

Create Ruby objects that validate themselves on instantiation, with clear error messages and flexible type checking including union types.

Result: Invalid objects can't be instantiated. Illegal states are unrepresentable.

```ruby
class Person < ValidatedObject::Base
  validates_attr :name, presence: true
  validates_attr :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end

Person.new(name: 'Alice', email: 'alice@example.com')  # ✓ Valid
Person.new(name: '', email: 'invalid')  # ✗ ArgumentError: "Name can't be blank; Email is invalid"
```

## Key Features

* **Union Types**: `union(String, Integer)` for flexible type validation
* **Array Element Validation**: `type: [String]` ensures arrays contain specific types  
* **Clear Error Messages**: Descriptive validation failures for debugging
* **Rails Validations**: Full ActiveModel::Validations support
* **Immutable Objects**: Read-only attributes with validation

Perfect for data imports, API boundaries, and structured data generation.

## Basic Usage

### Simple Validation

```ruby
class Dog < ValidatedObject::Base
  validates_attr :name, presence: true
  validates_attr :age, type: Integer, allow_nil: true
end

spot = Dog.new(name: 'Spot', age: 3)
spot.valid? # => true
```

### Type Validation

```ruby
class Document < ValidatedObject::Base
  validates_attr :title, type: String
  validates_attr :published_at, type: Date, allow_nil: true
  validates_attr :active, type: Boolean
end
```

The `Boolean` type accepts `true` or `false` values.

## Union Types

Union types allow attributes to accept multiple possible types:

### Basic Union Types

```ruby
class Article < ValidatedObject::Base
  # ID can be either a String or Integer
  validates_attr :id, type: union(String, Integer)
  
  # Status can be specific symbol values
  validates_attr :status, type: union(:draft, :published, :archived)
end

article = Article.new(id: "abc123", status: :published)  # ✓ String ID
article = Article.new(id: 42, status: :draft)            # ✓ Integer ID
Article.new(id: 3.14, status: :invalid)                  # ✗ ArgumentError
```

### Mixed Type and Array Unions

```ruby
class Post < ValidatedObject::Base
  # Author can be a Person object or Organization object
  validates_attr :author, type: union(Person, Organization)
  
  # Tags can be a single string or array of strings
  validates_attr :tags, type: union(String, [String])
  
  # Categories supports multiple formats
  validates_attr :categories, type: union(String, [String], [Category])
end

# All of these are valid:
Post.new(author: person, tags: "ruby")
Post.new(author: org, tags: ["ruby", "rails"])  
Post.new(author: person, categories: [category1, category2])
```

### Schema.org Example

Union types are perfect for Schema.org structured data:

```ruby
class Organization < ValidatedObject::Base
  # Address can be text or structured PostalAddress
  validates_attr :address, type: union(String, PostalAddress)
  
  # Founder can be Person or Organization
  validates_attr :founder, type: union(Person, Organization, [Person], [Organization])
  
  # Logo can be URL string or ImageObject  
  validates_attr :logo, type: union(String, ImageObject)
end
```

## Array Element Validation

Validate that arrays contain specific types:

```ruby
class Playlist < ValidatedObject::Base
  validates_attr :songs, type: [Song]           # Array of Song objects
  validates_attr :genres, type: [String]        # Array of strings
  validates_attr :ratings, type: [Integer]      # Array of integers
end

playlist = Playlist.new(
  songs: [song1, song2],
  genres: ["rock", "jazz"],  
  ratings: [4, 5, 3]
)
```

## Alternative Syntax

You can also use the standard Rails `validates` method:

```ruby
class Dog < ValidatedObject::Base
  attr_reader :name, :birthday

  validates :name, presence: true
  validates :birthday, type: union(Date, DateTime), allow_nil: true
end
```

## Error Messages

ValidatedObject provides clear, actionable error messages:

```ruby
doc = Document.new(title: 123, status: :invalid)
# => ArgumentError: Title is a Integer, not a String; Status is a Symbol, not one of :draft, :published, :archived

post = Post.new(tags: [123, "valid"])  
# => ArgumentError: Tags is a Array, not one of String, Array of String
```

## Use Cases

### Data Import Validation

```ruby
# Import CSV with validation
valid_records = []
CSV.foreach('data.csv', headers: true) do |row|
  begin
    valid_records << Person.new(row.to_h)
  rescue ArgumentError => e
    logger.warn "Invalid row: #{e.message}"
  end
end
```

### API Response Objects

```ruby
class ApiResponse < ValidatedObject::Base
  validates_attr :data, type: union(Hash, [Hash])
  validates_attr :status, type: union(:success, :error)
  validates_attr :message, type: String, allow_nil: true
end
```

### Schema.org Structured Data

The [Schema.org gem](https://github.com/public-law/schema-dot-org) uses ValidatedObject for type-safe structured data generation.

## Installation

Add to your Gemfile:

```ruby
gem 'validated_object'
```

Then run:
```bash
bundle install
```

## Development

After checking out the repo:

```bash
bin/setup          # Install dependencies
bundle exec rspec  # Run tests  
bin/console        # Interactive prompt
```

## Contributing

Bug reports and pull requests welcome on GitHub.

## License

Available as open source under the [MIT License](http://opensource.org/licenses/MIT).

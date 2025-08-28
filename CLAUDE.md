# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development Setup
- `bin/setup` - Install dependencies (runs `bundle install`)
- `bin/console` - Start an interactive console with the gem loaded

### Testing and Quality
- `rake spec` or `bundle exec rspec` - Run the test suite
- `bundle exec rubocop` - Run code linting (with rubocop-rspec and rubocop-rake plugins)
- `rake` - Default task (runs specs)

### Gem Development
- `bundle exec rake install` - Install gem locally for testing
- `bundle exec rake release` - Release new version (updates version, creates git tag, pushes to rubygems.org)

## Architecture

This is a Ruby gem that provides self-validating Plain Old Ruby Objects using ActiveModel validations. The core architecture consists of:

### Main Components

**ValidatedObject::Base** (`lib/validated_object.rb`):
- The main class that objects inherit from to gain validation capabilities
- Includes `ActiveModel::Validations` for standard Rails validation methods
- Automatically validates objects during instantiation via `initialize`
- Provides `check_validations!` method for explicit validation with clear error messages
- Contains a custom `TypeValidator` that supports type checking including arrays and pseudo-boolean validation

**ValidatedObject::SimplifiedApi** (`lib/validated_object/simplified_api.rb`):
- Provides convenience methods like `validates_attr` that combine `attr_reader` and `validates` 
- Supports streamlined array element type validation with `[ElementType]` syntax
- Allows `validated` as synonym for `validates`

### Key Features

- **Type Validation**: Custom `TypeValidator` supports class validation, pseudo-boolean (`Boolean` class), and array element type checking
- **Array Element Validation**: Two syntaxes supported:
  - `validates_attr :tags, type: Array, element_type: String`
  - `validates_attr :tags, type: [String]` (streamlined syntax)
- **Immutable Objects**: Uses `attr_reader` with instance variable setting to create read-only validated objects
- **Clear Error Messages**: Validation failures provide descriptive messages like "Birthday is a String, not a Date"

### Validation Patterns

The gem follows a declarative pattern where classes define their validation rules upfront:

```ruby
class Dog < ValidatedObject::Base
  validates_attr :name, presence: true
  validates_attr :birthday, type: Date, allow_nil: true
  validates_attr :tags, type: [String], allow_nil: true
end
```

Objects validate themselves during instantiation and raise `ArgumentError` with detailed messages if invalid.

## Development Notes

- Requires Ruby 3.1+
- Uses RSpec for testing with color output enabled
- RuboCop configured with rspec and rake plugins
- Gem specification allows pushing to rubygems.org
- Demo script available at `script/demo.rb`
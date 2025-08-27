require 'date'
require 'validated_object'

class Dog < ValidatedObject::Base
  attr_reader :name, :birthday

  validates :name, presence: true
  validates :birthday, type: Date, allow_nil: true
end

phoebe = Dog.new(name: 'Phoebe')
puts phoebe.inspect

maru = Dog.new(birthday: Date.today, name: 'Maru')
puts maru.inspect

hiro = Dog.new(birthday: 'today')
puts hiro.inspect

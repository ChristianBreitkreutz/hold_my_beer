# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.required_ruby_version = '>= 2.6.0'
end
# frozen_string_literal: true

require 'hold_my_beer'

RSpec.describe HoldMyBeer do
  it '.hi' do
    expect(HoldMyBeer.hi).to be('Wait, hold my beer!')
  end
end

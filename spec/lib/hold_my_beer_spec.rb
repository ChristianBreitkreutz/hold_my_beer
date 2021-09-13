# frozen_string_literal: true

# Gem::Specification.new do |spec|
#   spec.required_ruby_version = '>= 2.6.0'
# end
# frozen_string_literal: true

require 'hold_my_beer'
# require 'i18n'
RSpec.describe HoldMyBeer do
  it '.hi' do
    # I18n.load_path << Dir[File.expand_path("fixtures/config/locales") + "/*.yml"]
    # I18n.default_locale = :en # (note that `en` is already the default!)
    #pp I18n.t(:test)
    expect(HoldMyBeer.new.hi).to be('Wait, hold my beer!')
  end
end

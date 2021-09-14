# frozen_string_literal: true

require 'spec_helper'
require 'i18n_matcher'
require 'i18n'

RSpec.describe I18nMatcher do
  it 'asdfasd' do
    I18n.load_path << Dir[File.expand_path("fixtures/config/locales") + "/*.yml"]
    I18n.config.available_locales = :de
    I18n.default_locale = "de"
    pp I18n.with_locale(:de) { I18n.t('test') }
    # expect(I18nMatcher.new.translation_for_language!(:en, 'wurst'))
    #   .to be_a(I18nMatcher)
  end
end
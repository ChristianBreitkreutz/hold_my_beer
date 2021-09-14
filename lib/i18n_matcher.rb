# frozen_string_literal: true

class I18nMatcher
  attr_accessor :reason, :parameters, :system_wide_locales

  class InvalidTranslation < StandardError
    attr_accessor :reason, :parameters

    def initialize(reason, parameters)
      @reason = []
      @reason << reason
      @parameters = parameters
    end

    def message
      "#{@reason} - #{@parameters}"
    end
  end
  
  def translation_for_language!(locale, translation_key)
    translation = I18n.with_locale(locale) { I18n.t(translation_key) }
    parameters =  { locale: locale, translation_key: translation_key }
    if translation.nil?
      raise InvalidTranslation.new("A translation key is nil!", parameters)
    end
    if translation.include?("translation missing: #{locale}.#{translation_key}")
      raise InvalidTranslation.new("A translation key is missing", parameters)
    end

    true
  end
end
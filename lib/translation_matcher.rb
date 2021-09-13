# frozen_string_literal: true

class TranslationMatcher
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

  def initialize
    @system_wide_locales = Rails.application.config.x.system_wide_locales
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

  def translation_for_language?(locale, translation_key)
    catch_invalid_translation_and_store_in_stack do
      translation_for_language!(locale, translation_key)
    end
  end

  def exists_for_all_languages!(translation_key)
    for_all_languages do |locale|
      translation_for_language!(locale, translation_key)
    end
  end

  def exists_for_all_languages?(translation_key)
    catch_invalid_translation_and_store_in_stack do
      exists_for_all_languages!(translation_key)
    end
  end

  def translation_for_language_with_values!(locale, translation_key, *expected_values)
    translation_for_language!(locale, translation_key)
    translation = I18n.with_locale(locale) { I18n.t(translation_key) }
    all_translation_keys = translation_keys_syntax_supported_by_i18n(translation)
    expected_values ||= []
    expected_values.map!(&:to_s)
    if all_translation_keys.sort != expected_values.sort
      raise InvalidTranslation.new(
        "Unexpected translation keys", {
          locale: locale,
          translation_key: translation_key,
          expected_values: expected_values.sort,
          "values in translation text" => all_translation_keys.sort,
        }
      )
    end
    true
  end

  def translation_for_language_with_values?(locale, translation_key, *expected_values)
    catch_invalid_translation_and_store_in_stack do
      translation_for_language_with_values!(locale, translation_key, *expected_values)
    end
  end

  def exists_for_all_language_with_values!(translation_key, *expected_values)
    for_all_languages do |locale|
      translation_for_language_with_values!(locale, translation_key, *expected_values)
    end
  end

  def exists_for_all_language_with_values?(translation_key, *expected_values)
    catch_invalid_translation_and_store_in_stack do
      exists_for_all_language_with_values!(translation_key, *expected_values)
    end
  end

  def translation_for_languages_with_values_for_file!(locale, translation_key, translation_file, *expected_keys)
    translation_for_language_with_values!(locale, translation_key, *expected_keys)
    translations = load_translation_file(locale, translation_file)
    key_path = I18n.normalize_keys(locale, translation_key, nil, nil)

    translation_in_file = translations.dig(*key_path)
    if translation_in_file.nil?
      raise InvalidTranslation.new(
        "The translation key don't exist in translation config", {
          translations: translations,
          key_path: key_path,
        }
      )
    end

    translation_keys_from_file = translation_keys_syntax_supported_by_i18n(translation_in_file)
    expected_keys ||= []
    expected_keys.map!(&:to_s).sort
    if translation_keys_from_file != expected_keys
      raise InvalidTranslation.new(
        "The translation contains unexpected key(s)", {
          locale: locale,
          translations: translations,
          expected_keys: expected_keys,
          translation_keys_from_file: translation_keys_from_file,
        }
      )
    end
    true
  rescue InvalidTranslation => error
    error.reason.push("for transfile")
    error.parameters[:translation_file] = translation_file
    error.parameters[:expected_keys] = expected_keys
    raise error
  end

  def translation_for_languages_with_values_for_file?(locale, translation_key, translation_file, *expected_keys)
    catch_invalid_translation_and_store_in_stack do
      translation_for_languages_with_values_for_file!(
        locale, translation_key, translation_file,
        *expected_keys
      )
    end
  end

  def translation_for_all_languages_with_values_for_file!(translation_key, translation_file, *expected_keys)
    for_all_languages do |locale|
      translation_for_languages_with_values_for_file!(
        locale, translation_key, translation_file,
        *expected_keys
      )
    end
  end

  def translation_for_all_languages_with_values_for_file?(translation_key, translation_file, *expected_keys)
    catch_invalid_translation_and_store_in_stack do
      translation_for_all_languages_with_values_for_file!(
        translation_key, translation_file,
        *expected_keys
      )
    end
  end

  def check_if_template_contains_translation!(text, locale, translation_key, *replace_values)
    replace_values = replace_values.first
    if replace_values.nil?
      exists_for_all_languages!(translation_key)
      translation = I18n.with_locale(locale) { I18n.t(translation_key) }
    else
      exists_for_all_language_with_values!(translation_key, *replace_values.keys)
      translation = I18n.with_locale(locale) { I18n.t(translation_key, replace_values) }
    end

    return true if html_save_match?(text, translation)

    parameters = {
      locale: locale,
      translation_key: translation_key,
      replace_values: replace_values,
      "rendered translation" => translation,
      "original translation" => I18n.with_locale(locale) { I18n.t(translation_key) },
      "expected text" => text,
    }
    if replace_values.present?
      parameters["original translation"] = I18n.with_locale(locale) do
        I18n.t(translation_key)
      end
    end
    raise InvalidTranslation.new("The Text don't contain the translation", parameters)
  end

  def check_if_template_contains_translation?(text, locale, translation_key, *replace_values)
    catch_invalid_translation_and_store_in_stack do
      check_if_template_contains_translation!(text, locale, translation_key, *replace_values)
    end
  end

  def check_if_text_contains_translated_link!(text, locale, translation_key, path, *replace_values)
    replace_values = replace_values.first
    if replace_values.nil?
      exists_for_all_languages!(translation_key)

      translation = I18n.with_locale(locale) { I18n.t(translation_key) }
    else
      exists_for_all_language_with_values!(
        translation_key,
        *replace_values.keys,
      )

      translation = I18n.with_locale(locale) { I18n.t(translation_key, replace_values) }
    end
    # TODO: html_save_match?(text, translation)
    return true if text.match?(/<a href="#{path}">#{translation}<\/a>/) || text.match?(/<a href="#{path}">#{CGI.escapeHTML(translation)}<\/a>/)
      raise InvalidTranslation.new(
        "Link not found", {
          translation: translation,
          path: path,
        }
      )
  end

  def check_if_text_contains_translated_link?(text, locale, translation_key, path, *replace_values)
    catch_invalid_translation_and_store_in_stack do
      check_if_text_contains_translated_link!(text, locale, translation_key, path, *replace_values)
    end
  end

  def check_if_template_contains_translation_for_file!(text, locale, translation_key, translation_file, *expected_values)
    translations = load_translation_file(locale, translation_file)
    key_path = I18n.normalize_keys(locale, translation_key, nil, nil)

    translation_in_file = translations.dig(*key_path)
    if translation_in_file.nil?
      raise InvalidTranslation.new(
        "The translation key don't exist in translation config", {
          translations: translations,
          "translation key path" => key_path,
        }
      )
    end

    rendered_string = I18n.interpolate(translation_in_file, expected_values.first)

    return true if html_save_match?(text, rendered_string)

    raise InvalidTranslation.new(
      "The text don't contain the translation from file", {
        text: text,
        translation_in_file: translation_in_file,
      }
    )
  rescue InvalidTranslation => error
    error.parameters[:locale] = locale
    error.parameters[:translation_key] = translation_key
    error.parameters[:translation_file] = translation_file
    error.parameters[:expected_values] = expected_values

    raise error
  end

  def check_if_template_contains_translation_for_file?(text, locale, translation_key, translation_file, *expected_values)
    catch_invalid_translation_and_store_in_stack do
      check_if_template_contains_translation_for_file!(
        text, locale, translation_key,
        translation_file, *expected_values
      )
    end
  end

  private

  def html_save_match?(text, translation)
    return true if text.match? /#{translation}/
    return true if text.match? /#{CGI.escapeHTML(translation)}/

    false
  end

  def load_translation_file(locale, translation_file)
    localized_file_name = "#{translation_file}.#{locale}.yml"
    path = Rails.root.join("config", "locales", localized_file_name)
    HashWithIndifferentAccess.new(YAML.load_file(path))
  rescue Errno::ENOENT => error
    if error.to_s.include?(path.to_s)
      raise InvalidTranslation.new(
        "Unable to load translation file", { file_path: path.to_s }
      )
    else
      raise error
    end
  end

  def translation_keys_syntax_supported_by_i18n(translation)
    all_matches = translation.scan(
      Regexp.union(I18n.config.interpolation_patterns),
    )
    all_matches.map(&:pop) # pop out the value of the annotated string %<number>(.d)
    all_matches.flatten.uniq.compact
  end

  def for_all_languages(&block)
    @system_wide_locales.each(&block)
    true
  rescue InvalidTranslation => error
    error.reason.push("for one language")
    error.parameters[:system_wide_locales] = @system_wide_locales
    raise error
  end

  def catch_invalid_translation_and_store_in_stack
    yield
  rescue InvalidTranslation => error
    store_error_in_stack(error)
    false
  end

  def store_error_in_stack(e)
    @reason = e.reason
    @parameters = e.parameters
  end
end

#
# Matcher !
#
RSpec::Matchers.define :have_a_translation_for_language do |locale|
  with_failure_message do |translation_matcher|
    match do |translation_key|
      translation_matcher.translation_for_language?(locale, translation_key)
    end
  end
end

RSpec::Matchers.define :have_a_translation_for_all_languages do
  with_failure_message do |translation_matcher|
    match do |translation_key|
      translation_matcher.exists_for_all_languages?(translation_key)
    end
  end
end

RSpec::Matchers.define :have_a_translation_with_keys_for_language do |locale, expected_keys|
  with_failure_message do |translation_matcher|
    match do |translation_key|
      translation_matcher.translation_for_language_with_values?(
        locale, translation_key,
        *expected_keys
      )
    end
  end
end

RSpec::Matchers.define :have_a_translation_with_keys_for_all_languages do |expected_keys|
  with_failure_message do |translation_matcher|
    match do |translation_key|
      translation_matcher.exists_for_all_language_with_values?(
        translation_key,
        *expected_keys,
      )
    end
  end
end

RSpec::Matchers.define :have_a_overridden_translation_with_keys_for_language do |locale, translation_file, expected_keys|
  with_failure_message do |translation_matcher|
    match do |translation_key|
      translation_matcher.translation_for_languages_with_values_for_file?(
        locale, translation_key,
        translation_file, *expected_keys
      )
    end
  end
end

RSpec::Matchers.define :have_a_overridden_translation do |translation_file, *expected_keys|
  with_failure_message do |translation_matcher|
    match do |translation_key|
      translation_matcher.translation_for_all_languages_with_values_for_file?(
        translation_key,
        translation_file, *expected_keys
      )
    end
  end
end

RSpec::Matchers.define :contain_the_translation_key do |translation_key, *replace_variables|
  with_failure_message do |translation_matcher|
  match do |expected_text|
      translation_matcher.check_if_template_contains_translation?(
        expected_text,
        I18n.locale,
        translation_key,
        *replace_variables,
      )
    end
  end
end

RSpec::Matchers.define :contain_the_translated_link do |translation_key, path, *replace_variables|
  with_failure_message do |translation_matcher|
    match do |expected_text|
      translation_matcher.check_if_text_contains_translated_link?(
        expected_text,
        I18n.locale,
        translation_key,
        path,
        *replace_variables,
      )
    end
  end
end

RSpec::Matchers.define :contain_the_overridden_translation_key do |translation_key, file, *replace_variables|
  with_failure_message do |translation_matcher|
    match do |expected_text|
      translation_matcher.check_if_template_contains_translation_for_file?(
        expected_text,
        I18n.locale,
        translation_key,
        file,
        *replace_variables,
      )
    end
  end
end


def with_failure_message
  translation_matcher = TranslationMatcher.new
  yield(translation_matcher)
  failure_message do
    str = translation_matcher.reason.join("\n")
    str += hash_to_error_message(translation_matcher.parameters)
    str
  end
end

def hash_to_error_message(hash)
  output_string = ""
  hash.each do |key, value|
    output_string += "\n\t#{key}: '#{value}'"
  end
  output_string
end

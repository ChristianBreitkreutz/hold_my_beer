# frozen_string_literal: true

require "rails_helper"

# Issue 2, handle this path thing "admins.accounts.show_full_name" wirft kein fehler, obwohl "account.admins.accounts.show_full_name"
# relativ keys ".header" #  scope: :pages
# system_wide_locales
#  "Hello %{name}" will man nicht , aber was ist wenn man zuviel variablen hat? ist das ein usecase?
# %<number>06d
# die rescue nochmal nachschauen. da können sachen hängen bleiben
# die test files woanders
RSpec.describe TranslationMatcher do
  describe "#translation_for_language?" do
    it "is true if there is a translation for this key" do
      build_translation(:en, some_key: "some_value")
      result = described_class.new.translation_for_language?(:en, :some_key)
      expect(result).to be(true)
    end

    it "is falsey if the expected key doesnt exist" do
      build_translation(:en, some_key: "some_value")
      result = described_class.new.translation_for_language?(:en, :other_key)
      expect(result).to be_falsey
    end

    it "is falsey if the expected key exist, but is 'nil'" do
      build_translation(:en, some_key: nil)
      result = described_class.new.translation_for_language?(:en, :some_key)
      expect(result).to be_falsey
    end

    it "is true for a nested translation key" do
      nested_translation_hash = { some: { nested: { trans: { key: "value" } } } }
      build_translation(:en, nested_translation_hash)
      result = described_class.new.translation_for_language?(
        :en,
        "some.nested.trans.key",
      )
      expect(result).to be(true)
    end
  end

  describe "#exists_in_all_languages?" do
    it "is true with existing keys in all supported languages" do
      Rails.application.config.x.system_wide_locales = [:en, :fr]
      build_translation(:en, some_key: "some_value")
      build_translation(:fr, some_key: "some_value")
      result = described_class.new.exists_for_all_languages?("some_key")
      expect(result).to be(true)
    end

    it "is falsey if one language don't have the key" do
      Rails.application.config.x.system_wide_locales = [:de, :it]
      build_translation(:de, some_key: "some_value")
      result = described_class.new.exists_for_all_languages?("some_key")
      expect(result).to be_falsey
    end

    it "is falsey if on language have the key, but its 'nil'" do
      Rails.application.config.x.system_wide_locales = [:de, :fr]
      build_translation(:fr, some_key: "some_value")
      build_translation(:de, some_key: nil)
      result = described_class.new.exists_for_all_languages?("some_key")
      expect(result).to be_falsey
    end
  end

  describe "translation_for_language_with_values?" do
    it "is true if the translation contains no key and the is no key expected" do
      build_translation(:en, greeting: "Hello")
      result = described_class.new.translation_for_language_with_values?(
        :en,
        :greeting,
      )
      expect(result).to be(true)
    end

    it "is true if the translation contains the expected key" do
      build_translation(:en, greeting: "Hello %{name}")
      result = described_class.new.translation_for_language_with_values?(
        :en,
        :greeting,
        :name,
      )
      expect(result).to be(true)
    end

    it "is true if there as much keys in translation as expected" do
      build_translation(:en, greeting: "Hello %{name} a%{value}a")
      result = described_class.new.translation_for_language_with_values?(
        :en,
        :greeting,
        :name, :value
      )
      expect(result).to be(true)
    end

    it "is true for variables with pipe" do
      build_translation(:en, greeting: "test %{some|pipe}")
      result = described_class.new.translation_for_language_with_values?(
        :en,
        :greeting,
        :"some|pipe",
      )
      expect(result).to be(true)
    end

    it "is true for variables with annotated strings" do
      build_translation(:en, greeting: "text %<number>06d")
      result = described_class.new.translation_for_language_with_values!(
        :en,
        :greeting,
        :number,
      )
      expect(result).to be(true)
    end

    it "is true for variables with mixed types" do
      build_translation(:en, greeting: "%{normal} %{with|pipe} %<number>06d")
      result = described_class.new.translation_for_language_with_values!(
        :en,
        :greeting,
        :normal, :"with|pipe", :number
      )
      expect(result).to be(true)
    end

    it "is falsey if the key is missing for the expected language" do
      build_translation(:de, greeting: "Hello %{name} a%{value}a")
      result = described_class.new.translation_for_language_with_values?(
        :en,
        :greeting,
        :name, :value
      )
      expect(result).to be_falsey
    end

    context "With different amounts of translation keys" do
      it "is falsey if there more keys in translation as expected" do
        build_translation(:en, greeting: "Hello %{name} a%{value}a")
        result = described_class.new.translation_for_language_with_values?(
          :en,
          :greeting,
          :name,
        )
        expect(result).to be_falsey
      end

      it "is falsey if there no translation keys but one is expected" do
        build_translation(:en, greeting: "no translation keys")
        result = described_class.new.translation_for_language_with_values?(
          :en,
          :greeting,
          :name,
        )
        expect(result).to be_falsey
      end

      it "is false if there 2 keys and 2 expectations, but the key names are not matching" do
        build_translation(:en, greeting: "Hello %{name} a%{other}a")
        result = described_class.new.translation_for_language_with_values?(
          :en,
          :greeting,
          :name, :value
        )
        expect(result).to be_falsey
      end

      it "is true if one key is used in the translation multiple times" do
        build_translation(:en, greeting: "Hello %{name} a%{value}a %{name}")
        result = described_class.new.translation_for_language_with_values?(
          :en,
          :greeting,
          :name, :value
        )
        expect(result).to be(true)
      end

      it "is true if there no translation values and no expected translation keys" do
        build_translation(:en, greeting: "Hello")
        result = described_class.new.translation_for_language_with_values?(
          :en,
          :greeting,
        )
        expect(result).to be(true)
      end
    end
  end

  describe "#translation_for_all_language_with_values?" do
    it "is true if all languages have the same key with the same values" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      build_translation(:en, greeting: "Hello %{name} a%{value}a")
      build_translation(:de, greeting: "Hi %{name} a%{value}a")
      result = described_class.new.exists_for_all_language_with_values?(
        :greeting,
        :name, :value
      )
      expect(result).to be(true)
    end

    it "is falsey if one translation misses a value" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      build_translation(:en, greeting: "Hello %{name} a%{value}a")
      build_translation(:de, greeting: "Hi %{name} avaluea")
      result = described_class.new.exists_for_all_language_with_values?(
        :greeting,
        :name, :value
      )
      expect(result).to be_falsey
    end
  end

  describe "#translation_for_languages_with_values_for_file?" do
    it "is true if the translation file 'translation_matcher' contain keys with values" do
      result = described_class.new.translation_for_languages_with_values_for_file?(
        :de,
        "test.key_with_values",
        "translation_matcher",
        :person,
      )
      expect(result).to be(true)
    end

    it "is falsey if translation file is missing for a language" do
      result = described_class.new.translation_for_languages_with_values_for_file?(
        :fr,
        "test.key_with_values",
        "translation_matcher",
        :person,
      )
      expect(result).to be_falsey
    end

    it "is falsey if the key doesn't exist" do
      result = described_class.new.translation_for_languages_with_values_for_file?(
        :de,
        "not.existing.key",
        "translation_matcher",
        :person,
      )
      expect(result).to be_falsey
    end
  end

  describe "#tanslation_for_all_languages_with_values_for_file?" do
    context "With file 'translation_matcher'" do
      it "is true if the translation file contain expected keys and values" do
        Rails.application.config.x.system_wide_locales = [:de, :en]
        result = described_class.new.translation_for_all_languages_with_values_for_file?(
          "test.key_with_values",
          "translation_matcher",
          :person,
        )
        expect(result).to be(true)
      end

      it "is falsey if the translation file differ in on language" do
        Rails.application.config.x.system_wide_locales = [:de, :en]
        result = described_class.new.translation_for_all_languages_with_values_for_file?(
          "test.key_with_values_fails",
          "translation_matcher",
          :person,
        )
        expect(result).to be_falsey
      end
    end
  end

  describe "#check_if_template_contains_translation?" do
    it "find translated text in template string with replaced vars" do
      build_translation(:en, greeting: "Hello %{first} a%{last}a")
      build_translation(:de, greeting: "Hallo %{first} a%{last}a")
      rendered = "<h1>'Hello Fritz aBaucha'</h1"
      result = described_class.new.check_if_template_contains_translation?(
        rendered,
        :en,
        :greeting,
        first: "Fritz",
        last: "Bauch",
      )
      expect(result).to be(true)
    end

    it "is falsey if the template doesn't contain the translation" do
      build_translation(:en, greeting: "Hello %{first} a%{last}a")
      build_translation(:de, greeting: "Hallo %{first} a%{last}a")
      rendered = "<h1>'Not Our text'</h1>"
      result = described_class.new.check_if_template_contains_translation?(
        rendered,
        :en,
        :greeting,
        first: "Fritz",
        last: "Bauch",
      )
      expect(result).to be_falsey
    end
  end

  describe "check_if_template_contains_translation_for_file?" do
    it "is true if the translation from file is the same as in the expected text" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      result = described_class.new.check_if_template_contains_translation_for_file?(
        "my Text one 111, two 222, again one 111abc123",
        :en,
        "test.multiple_keys",
        "translation_matcher",
        first: "111",
        second: "222",
      )
      expect(result).to be(true)
    end
  end

  context "rspec matcher - expect to" do
    describe "have_a_translation_for_language" do
      it "is true if all is fine" do
        build_translation(:en, some_key: "some_value")
        result = capture_rspec_matcher_expectation_result do
          expect("some_key").to have_a_translation_for_language(:en)
        end
        expect(result).to be(true)
      end

      it "check failure_message" do
        build_translation(:en, some_key: "some_value")
        result = capture_rspec_matcher_expectation_result do
          expect("other_key").to have_a_translation_for_language(:en)
        end
        expect(result).to eq("A translation key is missing\n\tlocale: 'en'\n\ttranslation_key: 'other_key'")
      end
    end

    describe "have_a_translation_for_all_languages" do
      it "is true if all is fine" do
        Rails.application.config.x.system_wide_locales = [:de, :en]
        build_translation(:en, some_key: "some_value")
        build_translation(:de, some_key: "some_value")
        result = capture_rspec_matcher_expectation_result do
          expect("some_key").to have_a_translation_for_all_languages
        end
        expect(result).to be(true)
      end

      it "check failure_message" do
        Rails.application.config.x.system_wide_locales = [:de, :en]
        build_translation(:en, some_key: "some_value")
        result = capture_rspec_matcher_expectation_result do
          expect("some_value").to have_a_translation_for_all_languages
        end
        expect(result).to eq("A translation key is missing\nfor one language\n\tlocale: 'de'\n\ttranslation_key: 'some_value'\n\tsystem_wide_locales: '[:de, :en]'")
      end
    end

    describe "have_a_translation_with_keys_for_language" do
      it "is true if all is fine" do
        build_translation(:en, some_key: "some_value %{first_name}")
        result = capture_rspec_matcher_expectation_result do
          expect("some_key").to have_a_translation_with_keys_for_language(:en, :first_name)
        end
        expect(result).to be(true)
      end

      it "check failure_message_when_negated" do
        build_translation(:en, some_key: "some_value %{first_name}")
        result = capture_rspec_matcher_expectation_result do
          expect("some_key").not_to have_a_translation_with_keys_for_language(:en, :first_name)
        end
        expect(result).to eq("expected \"some_key\" not to have a translation with keys for language :en and :first_name")
      end

      it "check failure_message" do
        build_translation(:en, some_key: "some_value %{first_name}")
        result = capture_rspec_matcher_expectation_result do
          expect("some_key").to have_a_translation_with_keys_for_language(:en, :other_key)
        end
        expect(result).to eq("Unexpected translation keys\n\tlocale: 'en'\n\ttranslation_key: 'some_key'\n\texpected_values: '[\"other_key\"]'\n\tvalues in translation text: '[\"first_name\"]'")
      end
    end

    describe "translation_for_all_language_with_values?" do
      it "is true if all is fine" do
        Rails.application.config.x.system_wide_locales = [:de, :en]
        build_translation(:en, some_key: "some_value %{first_name}")
        build_translation(:de, some_key: "some_value %{first_name}")
        result = capture_rspec_matcher_expectation_result do
          expect("some_key").to have_a_translation_with_keys_for_all_languages(:first_name)
        end
        expect(result).to be(true)
      end

      it "check failure_message_when_negated" do
        Rails.application.config.x.system_wide_locales = [:de, :en]
        build_translation(:en, some_key: "some_value %{first_name}")
        build_translation(:de, some_key: "some_value %{first_name}")
        result = capture_rspec_matcher_expectation_result do
          expect("some_key").not_to have_a_translation_with_keys_for_all_languages(:first_name)
        end
        expect(result).to eq("expected \"some_key\" not to have a translation with keys for all languages :first_name")
      end

      it "check failure_message" do
        Rails.application.config.x.system_wide_locales = [:de, :en]
        build_translation(:en, some_key: "some_value %{first_name}")
        build_translation(:de, some_key: "some_value %{last_name}")
        result = capture_rspec_matcher_expectation_result do
          expect("some_key").to have_a_translation_with_keys_for_all_languages(:other_key)
        end
        expect(result).to eq("Unexpected translation keys\nfor one language\n\tlocale: 'de'\n\ttranslation_key: 'some_key'\n\texpected_values: '[\"other_key\"]'\n\tvalues in translation text: '[\"last_name\"]'\n\tsystem_wide_locales: '[:de, :en]'")
      end
    end

    describe "have_a_overridden_translation_with_keys_for_language" do
      it "is true if all is fine" do
        result = capture_rspec_matcher_expectation_result do
          expect("test.key_with_values").to have_a_overridden_translation_with_keys_for_language(
            :en,
            :translation_matcher,
            :person,
          )
        end
        expect(result).to be(true)
      end

      it "check failure_message_when_negated" do
        result = capture_rspec_matcher_expectation_result do
          expect("test.key_with_values").not_to have_a_overridden_translation_with_keys_for_language(
            :en,
            :translation_matcher,
            :person,
          )
        end
        expect(result).to eq("expected \"test.key_with_values\" not to have a overridden translation with keys for language :en, :translation_matcher, and :person")
      end

      it "check failure_message" do
        result = capture_rspec_matcher_expectation_result do
          expect("not.in.translation.file").to have_a_overridden_translation_with_keys_for_language(
            :en,
            :translation_matcher,
            :person,
          )
        end
        expect(result).to eq("A translation key is missing\nfor transfile\n\tlocale: 'en'\n\ttranslation_key: 'not.in.translation.file'\n\ttranslation_file: 'translation_matcher'\n\texpected_keys: '[:person]'")
      end
    end
  end

  describe "have_a_overridden_translation" do
    it "is true if all is fine" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      result = capture_rspec_matcher_expectation_result do
        expect("test.key_with_values").to have_a_overridden_translation(
          :translation_matcher,
          :person,
        )
      end
      expect(result).to be(true)
    end

    it "check failure_message_when_negated" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      result = capture_rspec_matcher_expectation_result do
        expect("test.key_with_values").not_to have_a_overridden_translation(
          :translation_matcher,
          :person,
        )
      end
      expect(result).to eq("expected \"test.key_with_values\" not to have a overridden translation :translation_matcher and :person")
    end

    it "check failure_message" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      result = capture_rspec_matcher_expectation_result do
        expect("not.in.translation.file").to have_a_overridden_translation(
          :translation_matcher,
          :person,
        )
      end
      expect(result).to eq("A translation key is missing\nfor transfile\nfor one language\n\tlocale: 'de'\n\ttranslation_key: 'not.in.translation.file'\n\ttranslation_file: 'translation_matcher'\n\texpected_keys: '[:person]'\n\tsystem_wide_locales: '[:de, :en]'")
    end
  end

  describe "contain_the_translation" do
    it "is true if all is fine" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      build_translation(:en, some_key: "Welcome %{first_name}!")
      build_translation(:de, some_key: "Willkommen %{first_name}!")
      rendered = "<h1>Welcome Hans!</h1>"
      result = capture_rspec_matcher_expectation_result do
        expect(rendered).to contain_the_translation_key(:some_key, first_name: "Hans")
      end
      expect(result).to be(true)
    end

    it "is true if all is fine if language key is changed" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      build_translation(:en, some_key: "Welcome %{first_name}!")
      build_translation(:de, some_key: "Willkommen %{first_name}!")
      rendered = "<h1>Willkommen Hans!</h1>"
      result = capture_rspec_matcher_expectation_result do
        I18n.with_locale(:de) do
          expect(rendered).to contain_the_translation_key(:some_key, first_name: "Hans")
        end
      end
      expect(result).to be(true)
    end

    it "check failure_message" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      build_translation(:en, some_key: "Welcome %{first_name}!")
      build_translation(:de, some_key: "Willkommen %{first_name}!")
      rendered = "<h1>no not here</h1>"
      result = capture_rspec_matcher_expectation_result do
        expect(rendered).to contain_the_translation_key(:some_key, first_name: "Hans")
      end
      expect(result).to eq("The Text don't contain the translation\n\tlocale: 'en'\n\ttranslation_key: 'some_key'\n\treplace_values: '{:first_name=>\"Hans\"}'\n\trendered translation: 'Welcome Hans!'\n\toriginal translation: 'Welcome %{first_name}!'\n\texpected text: '<h1>no not here</h1>'")
    end

    it "its true if the translation key has no values and there no values expected" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      build_translation(:en, some_key: "Welcome!")
      build_translation(:de, some_key: "Willkommen")
      rendered = "<h1>Welcome!</h1>"
      result = capture_rspec_matcher_expectation_result do
        expect(rendered).to contain_the_translation_key(:some_key)
      end
      expect(result).to eq(true)
    end
  end

  describe "contain_the_overridden_translation_key" do
    it "is true if all is fine" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      rendered = "<h1>Hello Hans!</h1>"
      result = capture_rspec_matcher_expectation_result do
        expect(rendered).to contain_the_overridden_translation_key(
          "test.key_with_values",
          :translation_matcher,
          person: "Hans",
        )
      end
      expect(result).to be(true)
    end

    it "is true if all is fine if language key is changed" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      rendered = "<h1>Hallo Hans!</h1>"
      result = capture_rspec_matcher_expectation_result do
        I18n.with_locale(:de) do
          expect(rendered).to contain_the_overridden_translation_key(
            "test.key_with_values",
            :translation_matcher,
            person: "Hans",
          )
        end
      end
      expect(result).to be(true)
    end

    it "check failure_message_when_negated" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      rendered = "<h1>Hello Hans!</h1>"
      result = capture_rspec_matcher_expectation_result do
        expect(rendered).not_to contain_the_overridden_translation_key(
          "test.key_with_values",
          :translation_matcher,
          person: "Hans",
        )
      end
      expect(result).to eq("expected \"<h1>Hello Hans!</h1>\" not to contain the overridden translation key \"test.key_with_values\", :translation_matcher, and {:person=>\"Hans\"}")
    end

    it "check failure_message" do
      Rails.application.config.x.system_wide_locales = [:de, :en]
      rendered = "<h1>no match</h1>"
      result = capture_rspec_matcher_expectation_result do
        expect(rendered).to contain_the_overridden_translation_key(
          "test.key_with_values",
          :translation_matcher,
          person: "Hans",
        )
      end
      expect(result).to eq("The text don't contain the translation from file\n\ttext: '<h1>no match</h1>'\n\ttranslation_in_file: 'Hello %{person}'\n\tlocale: 'en'\n\ttranslation_key: 'test.key_with_values'\n\ttranslation_file: 'translation_matcher'\n\texpected_values: '[{:person=>\"Hans\"}]'")
    end
  end

  describe "#contain_the_translated_link" do
    it "will find the the expected link" do
      build_translation(:en, some_key: "link Text")
      build_translation(:de, some_key: "link Text")
      rendered = '<h1><a href="/my/path">link Text</a></h1>'
      result = capture_rspec_matcher_expectation_result do
        expect(rendered).to contain_the_translated_link(
                              :some_key,
                              "/my/path",
                              )
      end
      expect(result).to eq(true)
      end
    it "will recognize the missing translation: ':de'" do
      build_translation(:en, some_key: "link Text")
      rendered = '<h1><a href="/my/path">link Text</a></h1>'
      result = capture_rspec_matcher_expectation_result do
        expect(rendered).to contain_the_translated_link(
                                :some_key,
                              "/my/path",
       )
      end
      expect(result).to eq("A translation key is missing\nfor one language\n\tlocale: 'de'\n\ttranslation_key: 'some_key'\n\tsystem_wide_locales: '[:de, :en]'")
    end
  end

  # helpers

  def build_translation(locale, data)
    @backend ||= I18n::Backend::Simple.new
    @config ||= I18n::Config.new

    allow(I18n).to receive(:config).and_return(@config)
    allow(@config).to receive(:backend).and_return(@backend)
    I18n.backend.store_translations(locale, data)
  end

  def capture_rspec_matcher_expectation_result
    Thread.new do
      Thread.current.report_on_exception = false
      yield
    end.join
    true
  rescue RSpec::Expectations::ExpectationNotMetError => error
    error.message
  end
end

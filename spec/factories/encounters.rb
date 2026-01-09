FactoryBot.define do
  factory :encounter, class: Encounter do

    # Delegation to a revision established after-initialize in the model makes
    # factory construction a little fiddly.
    #
    initialize_with { new(revisions: build_list(:revision, 1, :for_encounter, current: true)) }

    raw_editor           { false }
    encounter_hero_image { Rack::Test::UploadedFile.new(Rails.root.join("spec", "fixtures", "example.jpg")) }
    location             { Faker::Address.full_address }
    price_per_seat       { rand(2499..50000) }
    price_physical       { rand(250..750) }
    currency             { SUPPORTED_TEST_CURRENCIES.sample() }

    trait :free do
      price_per_seat { 0 }
    end

    trait :physical_free do
      price_physical { 0 }
    end

    trait :physical_none do
      price_physical { nil }
    end
  end
end

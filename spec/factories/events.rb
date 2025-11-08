FactoryBot.define do
  factory :event, class: Event do

    # Delegation to a revision established after-initialize in the model makes
    # factory construction a little fiddly.
    #
    initialize_with { new(revisions: build_list(:revision, 1, :for_event, current: true)) }

    association :page

    raw_editor       { false }
    event_hero_image { Rack::Test::UploadedFile.new(Rails.root.join("spec", "fixtures", "example.jpg")) }
    starts_at        { Time.current.midnight + rand(2..4).days + 18.hours }
    ends_at          { starts_at + 3.hours }
    number_of_seats  { rand(10..50) }
    price_per_seat   { rand(2499..50000) }
    currency         { SUPPORTED_TEST_CURRENCIES.sample() }
    location         { Faker::Address.full_address }

    trait :free do
      price_per_seat { 0 }
    end

    trait :uncounted do
      number_of_seats { 0 }
    end

    trait :public_purchases do
      state { Event.states[:public_purchases] }
    end
  end
end

FactoryBot.define do
  factory :encounter_order, class: EncounterOrder do

    association :encounter

    name            { Faker::Name.name }
    email           { Faker::Internet.unique.email } # NOTE always unique
    phone_number    { "+6421000#{rand(111..999)}" }
    number_of_seats { rand(1..6) }
    amount_owed     { number_of_seats * encounter.price_per_seat }
    address         { Faker::Address.full_address }
    starts_at       { Time.now + 1.week }

    trait :discounted do
      amount_owed { number_of_seats * encounter.price_per_seat - (encounter.price_per_seat / 2) }
    end

    trait :with_buyer_notes do
      notes_to_buyer { Faker::Lorem.paragraph }
    end

    trait :with_gift_note do
      gift_note { Faker::Lorem.paragraph }
    end

    trait :has_physical do
      has_physical { true }
    end

    trait :no_physical do
      has_physical { false }
    end

    trait :open_ended do
      starts_at { nil }
    end
  end
end

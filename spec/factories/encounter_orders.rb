FactoryBot.define do
  factory :encounter_order, class: EncounterOrder do
    association :encounter

    name                        { Faker::Name.name }
    email                       { Faker::Internet.unique.email } # NOTE always unique
    phone_number                { "+6421000#{rand(111..999)}" }
    number_of_seats             { rand(1..6) }
    has_physical                { false }
    user_chooses_has_physical   { true }
    frozen_price_on_application { encounter&.price_on_application }
    frozen_price_per_seat       { encounter&.price_per_seat }
    frozen_price_physical       { encounter&.price_physical }
    amount_owed                 { self.theoretical_amount_owed_without_discounts() }
    address                     { Faker::Address.full_address }
    starts_at                   { Time.now + 1.week }

    trait :discounted do
      amount_owed { self.theoretical_amount_owed_without_discounts() - (encounter.price_per_seat / 2) }
    end

    trait :with_buyer_notes do
      notes_to_buyer { Faker::Lorem.paragraph }
    end

    trait :with_gift_note do
      gift_note { Faker::Lorem.paragraph }
    end

    trait :has_physical do
      user_chooses_has_physical { false }
      has_physical              { true  }
    end

    trait :no_physical do
      user_chooses_has_physical { false }
      has_physical              { false }
    end

    trait :open_ended do
      starts_at { nil }
    end
  end
end

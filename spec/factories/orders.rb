FactoryBot.define do
  factory :order, class: Order do

    association :event

    name            { Faker::Name.name }
    email           { Faker::Internet.unique.email } # NOTE always unique
    phone_number    { "+6421000#{rand(111..999)}" }
    number_of_seats { rand(2..([event.number_of_seats, 5].min)) }
    amount_owed     { number_of_seats * event.price_per_seat }
    address         { Faker::Address.full_address }

    trait :discounted do
      amount_owed { number_of_seats * event.price_per_seat - (event.price_per_seat / 2) }
    end

    trait :with_notes do
      notes { Faker::Lorem.paragraph }
    end
  end
end

FactoryBot.define do
  factory :revision, class: Revision do
    title { Faker::Lorem.sentence.chomp(".") }
    body  { "<p>#{Faker::Lorem.paragraph}</p>" }

    trait :for_page do
      navigation_title { Faker::Lorem.sentence.chomp(".") }
    end

    trait :for_article do
      summary { Faker::Lorem.paragraph }
    end
  end
end

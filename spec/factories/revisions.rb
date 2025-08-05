FactoryBot.define do
  factory :revision, class: Revision do
    title { Faker::Lorem.sentence.chomp(".") }
    body  { "<p>#{Faker::Lorem.paragraph}</p>" }

    trait :for_page do
      trait :with_nav_title do
        navigation_title { Faker::Lorem.sentence.chomp(".") }
      end
    end

    trait :for_article do
      summary { Faker::Lorem.paragraph }
    end
  end
end

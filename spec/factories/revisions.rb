FactoryBot.define do
  factory :revision, class: Revision do
    body { "<p>#{Faker::Lorem.paragraph}</p>" }

    title do
      begin
        available_title = Faker::Lorem.sentence.chomp(".")
      end while Revision.unscoped.where(title: available_title).any?

      available_title
    end

    trait :for_article do
      summary { Faker::Lorem.paragraph }
    end

    trait :for_encounter do
      summary { Faker::Lorem.paragraph }
    end

    trait :for_event do
      summary { Faker::Lorem.paragraph }
    end

    trait :for_page do
      navigation_title { Faker::Lorem.sentence.chomp(".") }
    end
  end
end

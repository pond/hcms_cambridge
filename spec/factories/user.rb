FactoryBot.define do
  factory :user, class: User do
    password              { Constants::DEFAULT_VALID_PASSWORD }
    password_confirmation { password }
    email                 { Faker::Internet.unique.email(name: Faker::Name.unique.first_name) }
  end
end

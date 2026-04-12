FactoryBot.define do
  factory :page, class: Page do

    # Delegation to a revision established after-initialize in the model makes
    # factory construction a little fiddly.
    #
    initialize_with { new(revisions: build_list(:revision, 1, :for_page, current: true)) }

    position   { Page.unscoped.count + 1 }
    hidden     { false }
    raw_editor { false }
    page_type  { Page::PAGE_TYPE_NORMAL }

    trait :with_nav_title do
      navigation_title { Faker::Lorem.sentence.chomp(".") }
    end

    trait :contact_form do
      page_type { Page::PAGE_TYPE_CONTACT_FORM }
    end

    trait :booking_form do
      page_type { Page::PAGE_TYPE_BOOKING_FORM }
    end

    trait :blog do
      page_type { Page::PAGE_TYPE_BLOG }
    end

    trait :events do
      page_type { Page::PAGE_TYPE_EVENTS }
    end

    trait :encounters do
      page_type { Page::PAGE_TYPE_ENCOUNTERS }
    end

    trait :with_menu do
      form_selection_list_contents { Faker::Lorem.words(number: 3).join("\n") }
      form_selection_list_label    { Faker::Lorem.question }
    end
  end
end

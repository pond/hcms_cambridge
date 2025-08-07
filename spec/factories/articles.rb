FactoryBot.define do
  factory :article, class: Article do

    # Delegation to a revision established after-initialize in the model makes
    # factory construction a little fiddly.
    #
    initialize_with { new(revisions: build_list(:revision, 1, :for_article, current: true)) }

    association :page

    raw_editor         { false }
    article_hero_image { Rack::Test::UploadedFile.new(Rails.root.join("spec", "fixtures", "example.jpg")) }
  end
end

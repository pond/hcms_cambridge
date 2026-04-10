require "spec_helper.rb"

RSpec.describe Encounter, type: :model do

  # A little helper to DRY things a tiny bit.
  #
  def expect_stripe_to_be_made_inactive_via(encounter, simulated_failure: false)
    mock_prodid  = "product_test_1234"
    mock_priceid = "price_test_1234"

    StripePrice.create!(priceable: encounter, stripe_price_id: mock_priceid)

    expect(Stripe::Price).to receive(:retrieve).with(mock_priceid).and_return double(id: mock_priceid, product: mock_prodid)
    expect(Stripe::Product).to receive(:retrieve).with(mock_prodid).and_return double(id: mock_prodid)

    expect(Stripe::Product).to receive(:update).with(mock_prodid, {active: false})

    if simulated_failure
      expect(Stripe::Price).to receive(:update) { raise "An error" }
    else
      expect(Stripe::Price).to receive(:update).with(mock_priceid, {active: false})
    end
  end

  it "is an Editable" do # (because that's tested separately, so no need to duplicate tests here)
    expect(Encounter.ancestors).to include(Editable)
  end

  context "scopes and associations" do
    it "default scope orders by category position, then category" do
      encounter_1 = create(:encounter, category_position: 2, category: "Caravan")
      encounter_2 = create(:encounter, category_position: 1, category: "Banana")
      encounter_3 = create(:encounter, category_position: 2, category: "Aardvark")

      expect(Encounter.all.to_a).to eql([encounter_2, encounter_3, encounter_1])
    end

    it "::for_navigation finds nothing" do
      encounter_1 = create(:encounter); encounter_1.revisions.update_all(published: false)
      encounter_2 = create(:encounter); encounter_2.revisions.update_all(published: true)
      encounter_3 = create(:encounter); encounter_3.revisions.update_all(published: true)

      expect(Encounter.for_navigation).to be_empty
    end

    it "::without_category" do
      encounter_1 = create(:encounter, category: "Caravan")
      encounter_2 = create(:encounter)
      encounter_3 = create(:encounter, category: "Aardvark")

      expect(Encounter.without_category.to_a).to eql([encounter_2])
    end

    it "::with_category" do
      encounter_1 = create(:encounter, category: "Caravan")
      encounter_2 = create(:encounter)
      encounter_3 = create(:encounter, category: "Aardvark")

      expect(Encounter.with_category.to_a).to eql([encounter_3, encounter_1])
    end

    it "::matching_category" do
      encounter_1 = create(:encounter, category: "Caravan")
      encounter_2 = create(:encounter)
      encounter_3 = create(:encounter, category: "Aardvark")

      expect(Encounter.matching_category("Aardvark").to_a).to eql([encounter_3])
      expect(Encounter.matching_category(""        ).to_a).to eql([encounter_2])
      expect(Encounter.matching_category("    "    ).to_a).to eql([encounter_2])
    end
  end # 'context "scopes and associations" do'

  context "category assistance" do
    it 'enumerates categories' do
      encounter_1 = create(:encounter, category: "Caravan")
      encounter_2 = create(:encounter)
      encounter_3 = create(:encounter, category: "Aardvark")

      expect(Encounter.categories).to eql(["Aardvark", "Caravan"])
    end

    it "matches categories (with lenient white space checks)" do
      encounter_1 = create(:encounter, category: "Caravan")
      encounter_2 = create(:encounter)
      encounter_3 = create(:encounter, category: "Aardvark")

      encounter = build(:encounter, category: "Aardvark")

      expect(encounter.category_matches?(encounter_1)).to eql(false)
      expect(encounter.category_matches?(encounter_2)).to eql(false)
      expect(encounter.category_matches?(encounter_3)).to eql(true)

      encounter = build(:encounter)

      expect(encounter.category_matches?(encounter_1)).to eql(false)
      expect(encounter.category_matches?(encounter_2)).to eql(true)
      expect(encounter.category_matches?(encounter_3)).to eql(false)

      encounter_2.update_column(:category, "                ")
      encounter = build(:encounter, category: "   ")

      expect(encounter.category_matches?(encounter_2)).to eql(true)
    end

    it "notes the first and last in a group" do
      encounter_1 = create(:encounter, category: "A", category_position: 1)
      encounter_2 = create(:encounter, category: "A", category_position: 1)
      encounter_3 = create(:encounter, category: "B", category_position: 2)
      encounter_4 = create(:encounter, category: "C", category_position: 3)
      encounter_5 = create(:encounter, category: "C", category_position: 3)

      expect(encounter_1.first?).to eql(true)
      expect(encounter_1.last? ).to eql(false)

      expect(encounter_2.first?).to eql(true)
      expect(encounter_2.last? ).to eql(false)

      expect(encounter_3.first?).to eql(false)
      expect(encounter_3.last? ).to eql(false)

      expect(encounter_4.first?).to eql(false)
      expect(encounter_4.last? ).to eql(true)

      expect(encounter_5.first?).to eql(false)
      expect(encounter_5.last? ).to eql(true)
    end
  end # 'context "category assistance" do'

  context "validations" do
    it "requires a title, summary, body and hero image" do
      encounter = build(:encounter)

      expect(encounter).to be_valid # (self-check)

      encounter.revisions.first.summary = nil

      expect(encounter).to_not be_valid
      expect(encounter.errors.of_kind?(:summary, :blank)).to eql(true)

      encounter.revisions.first.summary = "OK"

      expect(encounter).to be_valid

      encounter.revisions.first.body = nil

      expect(encounter).to_not be_valid
      expect(encounter.errors.of_kind?(:body, :blank)).to eql(true)

      encounter.revisions.first.body = "<p>OK</p>"

      expect(encounter).to be_valid

      encounter.encounter_hero_image = nil

      expect(encounter).to_not be_valid
      expect(encounter.errors.of_kind?(:encounter_hero_image, :blank)).to eql(true)
    end
  end # 'context "validations" do'

  it "responds correctly to trait enquiries" do
    encounter = build(:encounter)

    expect(encounter.is_normal_type?).to eql(false)
    expect(encounter.is_form_type?  ).to eql(false)
    expect(encounter.is_blog_type?  ).to eql(false)
    expect(encounter.is_events_type?).to eql(false)
    expect(encounter.is_article?    ).to eql(false)
    expect(encounter.is_encounter?  ).to eql(true)
    expect(encounter.is_event?      ).to eql(false)
  end

  context "base class overrides" do
    context "#for_navigation?" do
      it "returns 'false' always" do
        encounter_1 = create(:encounter); encounter_1.revisions.update_all(published: false)
        encounter_2 = create(:encounter); encounter_2.revisions.update_all(published: true)
        encounter_3 = create(:encounter); encounter_3.revisions.update_all(published: true)

        expect(encounter_1.for_navigation?).to eql(false)
        expect(encounter_2.for_navigation?).to eql(false)
        expect(encounter_3.for_navigation?).to eql(false)
      end
    end # 'context "#for_navigation?" do'
  end # 'context "base class overrides" do'

  context "miscellaneous" do
    it '#price_on_application?' do
      priced_encounter = build(:encounter)
      free_encounter   = build(:encounter, :free)

      # The POA flag should override any setting of price-per-seat.
      #
      priced_encounter.price_on_application = true
        free_encounter.price_on_application = true

      expect(priced_encounter.price_on_application?).to eql(true)
      expect(  free_encounter.price_on_application?).to eql(true)
    end

    it "#free_of_charge?" do
      priced_encounter = build(:encounter)
      free_encounter   = build(:encounter, :free)

      expect(priced_encounter.free_of_charge?).to eql(false)
      expect(  free_encounter.free_of_charge?).to eql(true)

      # The POA flag should override price-per-seat-is-zero; the encounter is
      # *not* free of charge.
      #
      free_encounter.price_on_application = true

      expect(  free_encounter.free_of_charge?).to eql(false)
    end

    it "#no_physical_aspect?" do
      expect(build(:encounter                ).has_physical_aspect?).to eql(true)
      expect(build(:encounter, :physical_none).has_physical_aspect?).to eql(false)
    end

    it "#physical_aspect_free_of_charge?" do
      expect(build(:encounter                ).physical_aspect_free_of_charge?).to eql(false)
      expect(build(:encounter, :physical_free).physical_aspect_free_of_charge?).to eql(true)
    end

    context '#get_or_create_stripe_price' do
      it 'when the encounter has no stripe price attached' do
        mock_prodid        = "product_test_1234"
        mock_priceid       = "price_test_1234"
        mock_encounter_url = "https://www.example.com/encounter"
        encounter          = create(:encounter)

        expect(Stripe::Product).to receive(:create) do | args |
          expect(args[:name       ]     ).to eql(encounter.title)
          expect(args[:description]     ).to be_nil # (note how this differs from Events)
          expect(args[:images     ].size).to eql(1)
          expect(args[:images     ][0]  ).to eql(encounter.product_image_url())
          expect(args[:shippable  ]     ).to eql(false)
          expect(args[:unit_label ]     ).to eql("seat")
          expect(args[:url        ]     ).to eql(mock_encounter_url)

          double(:product, id: mock_prodid)
        end

        expect(Stripe::Price).to receive(:create) do | args |
          expect(args[:currency   ]).to eql(encounter.currency)
          expect(args[:unit_amount]).to eql(encounter.price_per_seat)
          expect(args[:product    ]).to eql(mock_prodid)

          double(:price, id: mock_priceid)
        end

        price = encounter.get_or_create_stripe_price(with_encounter_url: mock_encounter_url)

        expect(price                ).to be_present
        expect(price.encounter_id   ).to eql(encounter.id)
        expect(price.stripe_price_id).to eql(mock_priceid)
      end

      it 'when the encounter has a stripe price attached' do
        price_double = double(:price)
        encounter    = create(:encounter)

        expect(encounter.stripe_price).to be_nil # (self-check)

        allow(encounter).to receive(:stripe_price).and_return(price_double)

        expect(encounter.get_or_create_stripe_price(with_encounter_url: 'n/a')).to eql(price_double)
      end
    end # 'context '#get_or_create_stripe_price' do'
  end # 'context "miscellaneous" do'

  context "when destroyed" do
    it "makes an associated Stripe price inactive" do
      encounter = create(:encounter)

      expect_stripe_to_be_made_inactive_via(encounter)

      encounter.destroy!

      expect(Encounter.find_by_id(encounter.id)).to be_nil
    end
  end
end

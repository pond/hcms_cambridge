require "spec_helper.rb"

RSpec.describe EncounterOrderItem, type: :model do
  context "validations" do
    before :each do
      @encounter_order = create(:encounter_order)
    end

    context "presence" do
      it "checks for basic fields" do
        item = EncounterOrderItem.new(encounter_order: @encounter_order)

        expect(item).to_not be_valid

        [:description, :amount_owed].each do |attr|
          expect(item.errors.messages_for(attr)).to include("must be provided")
        end

        item.description = "Venue hire"
        item.amount_owed = 30000
        item.validate()

        [:description, :amount_owed].each do |attr|
          expect(item.errors.messages_for(attr)).to_not include("must be provided")
        end
      end
    end # 'context "presence" do'

    context "formats" do

      # Back-end formats human currency strings into smallest currency units as
      # an integer, but in case that has bugs, a must-be-integer validation is
      # included for the amount, along with a more useful "is > 0" check.
      #
      it "requires an integer (defensively) amount owed, which must be positive" do
        item = EncounterOrderItem.new(encounter_order: @encounter_order, description: "Venue hire")

        item.amount_owed = "hello"
        item.validate()

        expect(item.errors.messages_for(:amount_owed)).to include("must be a positive number")

        item.amount_owed = 3.5
        item.validate()

        expect(item.errors.messages_for(:amount_owed)).to include("must be a positive number")

        item.amount_owed = -2
        item.validate()

        expect(item.errors.messages_for(:amount_owed)).to include("must be a positive number")

        item.amount_owed = 1

        expect(item).to be_valid
      end
    end # 'context "formats" do'
  end # 'context "validations" do'
end

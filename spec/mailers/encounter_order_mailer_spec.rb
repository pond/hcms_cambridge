require "spec_helper"

# Tests elsewhere look at actual e-mail contents in detail, but there are basic
# regression tests here to make sure that sending seems to work at all.
#
RSpec.describe EncounterOrderMailer, type: :mailer do
  let(:canary_from) { "test-#{Time.now.usec}@test.com" }

  # The encounter orders e-mail address is the same as the orders address, so
  # it's correct to mock ":orders_email".
  #
  before :each do
    allow(Hcms.config).to receive(:orders_email).and_return(canary_from())
  end

  shared_examples "it has expected fields" do
    it "for subject, 'to', 'from' and body" do
      model = model_proc().call
      email = described_class.send(method(), model)

      expect(email.subject).to be_present
      expect(email.to     ).to eql([model.email])
      expect(email.from   ).to eql([canary_from()])

      expect(email.body.encoded).to be_present
    end
  end # 'shared_examples "it has expected fields" do'

  shared_examples "a working mailer" do
    context "#encounter_order_state_paid_email" do
      let(:method) { :encounter_order_state_paid_email }

      it_behaves_like "it has expected fields"
    end

    context "#encounter_order_state_payment_failed_email" do
      let(:method) { :encounter_order_state_payment_failed_email }

      it_behaves_like "it has expected fields"
    end

    context "#encounter_order_state_cancelled_email" do
      let(:method) { :encounter_order_state_cancelled_email }

      it_behaves_like "it has expected fields"
    end

    context "#encounter_order_state_refunded_email" do
      let(:method) { :encounter_order_state_refunded_email }

      it_behaves_like "it has expected fields"
    end
  end # 'shared_examples "a working mailer" do'

  # ============================================================================

  context "default factory" do
    let(:model_proc) { -> { create(:encounter_order) } }

    it_behaves_like "a working mailer"
  end

  context "without address" do
    let(:model_proc) { -> { create(:encounter_order, address: nil) } }

    it_behaves_like "a working mailer"
  end

  context "discounted" do
    let(:model_proc) { -> { create(:encounter_order, :discounted) } }

    it_behaves_like "a working mailer"
  end

  context "with buyer notes" do
    let(:model_proc) { -> { create(:encounter_order, :with_buyer_notes) } }

    it_behaves_like "a working mailer"
  end

  context "includes physical product" do
    let(:model_proc) { -> { create(:encounter_order, :has_physical) } }

    it_behaves_like "a working mailer"
  end

  context "excludes physical product" do
    let(:model_proc) { -> { create(:encounter_order, :no_physical) } }

    it_behaves_like "a working mailer"
  end

  context "open-ended start date" do
    let(:model_proc) { -> { create(:encounter_order, :open_ended) } }

    it_behaves_like "a working mailer"
  end
end

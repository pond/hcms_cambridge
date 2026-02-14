require "spec_helper"

# Tests elsewhere look at actual e-mail contents in detail, but there are basic
# regression tests here to make sure that sending seems to work at all.
#
RSpec.describe Admin::AdminMailer, type: :mailer do
  let(:canary_admin) { "test-#{Time.now.usec}@test.com" }

  # The encounter orders e-mail address is the same as the orders address, so
  # it's correct to mock ":orders_email" for everything here.
  #
  before :each do
    allow(Hcms.config).to receive(:orders_email).and_return(canary_admin())
  end

  shared_examples "it has expected fields" do
    it "for subject, 'to', 'from' and body" do
      model = model_proc().call
      email = described_class.send(method(), model)

      expect(email.subject).to be_present
      expect(email.to     ).to eql([canary_admin()])
      expect(email.from   ).to eql([canary_admin()])

      expect(email.body.encoded).to be_present
    end
  end # 'shared_examples "it has expected fields" do'

  # ============================================================================

  context "orders" do
    shared_examples "a working mailer" do
      context "#order_reserved" do
        let(:method) { :order_reserved }

        it_behaves_like "it has expected fields"
      end

      context "#order_paid" do
        let(:method) { :order_paid }

        it_behaves_like "it has expected fields"
      end

      context "#order_cancelled" do
        let(:method) { :order_cancelled }

        it_behaves_like "it has expected fields"
      end

      context "#problematic_order_email" do
        let(:method) { :problematic_order_email }

        it_behaves_like "it has expected fields"
      end
    end

    # ==========================================================================

    context "default factory" do
      let(:model_proc) { -> { create(:order) } }

      it_behaves_like "a working mailer"
    end

    context "without address" do
      let(:model_proc) { -> { create(:order, address: nil) } }

      before :each do
        allow(Hcms.config).to receive(:tax_threshold).and_return(nil)
      end

      it_behaves_like "a working mailer"
    end

    context "discounted" do
      let(:model_proc) { -> { create(:order, :discounted) } }

      it_behaves_like "a working mailer"
    end

    context "with notes" do
      let(:model_proc) { -> { create(:order, :with_notes) } }

      it_behaves_like "a working mailer"
    end

    context "with hard-deleted event" do
      let(:model_proc) { -> { o = create(:order); o.event.destroy!; o.event = nil; o } }

      it_behaves_like "a working mailer"
    end
  end # 'context "orders" do'

  # ============================================================================

  context "encounter orders" do
    shared_examples "a working mailer" do
      context "#encounter_order_paid" do
        let(:method) { :encounter_order_paid }

        it_behaves_like "it has expected fields"
      end

      context "#encounter_order_cancelled" do
        let(:method) { :encounter_order_cancelled }

        it_behaves_like "it has expected fields"
      end

      context "#problematic_encounter_order_email" do
        let(:method) { :problematic_encounter_order_email }

        it_behaves_like "it has expected fields"
      end
    end

    # ==========================================================================

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

    context "with hard-deleted encounter" do
      let(:model_proc) { -> { eo = create(:encounter_order); eo.encounter.destroy!; eo.encounter = nil; eo } }

      it_behaves_like "a working mailer"
    end
  end # 'context "encounter orders" do'
end

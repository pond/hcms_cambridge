require "spec_helper"

# Tests elsewhere look at actual e-mail contents in detail, but there are basic
# regression tests here to make sure that sending seems to work at all.
#
RSpec.describe OrderMailer, type: :mailer do
  let(:canary_from) { "test-#{Time.now.usec}@test.com" }

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
    context "#order_state_reserved_email" do
      let(:method) { :order_state_reserved_email }

      it_behaves_like "it has expected fields"
    end

    context "#order_state_paid_email" do
      let(:method) { :order_state_paid_email }

      it_behaves_like "it has expected fields"
    end

    context "#order_state_payment_failed_email" do
      let(:method) { :order_state_payment_failed_email }

      it_behaves_like "it has expected fields"
    end

    context "#order_state_cancelled_email" do
      let(:method) { :order_state_cancelled_email }

      it_behaves_like "it has expected fields"
    end

    context "#order_state_refunded_email" do
      let(:method) { :order_state_refunded_email }

      it_behaves_like "it has expected fields"
    end

    context "#event_state_reserver_purchases_email" do
      let(:method) { :event_state_reserver_purchases_email }

      it_behaves_like "it has expected fields"
    end

    context "#event_state_public_purchases_email" do
      let(:method) { :event_state_public_purchases_email }

      it_behaves_like "it has expected fields"
    end
  end # 'shared_examples "a working mailer" do'

  # ============================================================================

  context "default factory" do
    let(:model_proc) { -> { create(:order) } }

    it_behaves_like "a working mailer"
  end

  context "without address" do
    let(:model_proc) { -> { create(:order, address: nil) } }

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
end

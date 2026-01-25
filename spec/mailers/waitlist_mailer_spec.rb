require "spec_helper"

# Tests elsewhere look at actual e-mail contents in detail, but there are basic
# regression tests here to make sure that sending seems to work at all.
#
RSpec.describe WaitlistMailer, type: :mailer do
  let(:canary_admin) { "test-#{Time.now.usec}@test.com" }

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

  shared_examples "a working mailer" do
    context "#join_waitlist_request_email" do
      let(:method) { :join_waitlist_request_email }

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
end

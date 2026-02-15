require "spec_helper"

# Tests elsewhere look at actual e-mail contents in detail, but there are basic
# regression tests here to make sure that sending seems to work at all.
#
RSpec.describe BookingMailer, type: :mailer do
  let(:canary_booking) { "test-#{Time.now.usec}@test.com" }
  let(:page)           { create(:page, :booking_form) }

  before :each do
    allow(Hcms.config).to receive(:booking_email).and_return(canary_booking())
  end

  shared_examples "it has expected fields" do
    it "for subject, 'to', 'from' and body" do
      params = params_proc().call
      email  = described_class.send(method(), params)

      # Note that we can't fake a 'from' address to be that of the enquiring
      # end user, even if they

      expect(email.subject).to be_present
      expect(email.to     ).to eql([canary_booking()])
      expect(email.from   ).to eql([canary_booking()])

      expect(email.body.encoded).to be_present
    end
  end # 'shared_examples "it has expected fields" do'

  shared_examples "a working mailer" do
    context "#booking_email" do
      let(:method) { :booking_email }

      it_behaves_like "it has expected fields"
    end
  end

  # ============================================================================

  context "with all fields filled in" do
    let(:params_proc) { -> {
      Forms::Booking.new(
        page:           page(),
        name:           Faker::Name.name,
        email:          Faker::Internet.email,
        phone:          "+6421000#{rand(111..999)}",
        time:           "16:14",
        date:           "19/01/2038",
        menu_selection: "Menu item",
        notes:          Faker::Lorem.paragraph,
      )
    } }

    it_behaves_like "a working mailer"
  end

  context "with bare minimum fields filled in" do
    let(:params_proc) { -> {
      Forms::Booking.new(
        page:  page(),
        name:  Faker::Name.name,
        email: Faker::Internet.email,
      )
    } }

    it_behaves_like "a working mailer"
  end
end

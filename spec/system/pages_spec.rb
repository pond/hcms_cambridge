require "spec_helper.rb"
require_relative "shared_examples/footer_spec.rb"

RSpec.describe "Pages" do
  context "navigation" do
    it "shows only non-hidden, published pages with child drop-downs", js: true do
      page_1 = create(:page, hidden: true  ); page_1.revisions.first.update!(published: true) # Not in menu because is hidden, but is still the root/Home page
      page_2 = create(:page                ) # Not in menu because is only a draft
      page_3 = create(:page                ); page_3.revisions.first.update!(published: true)
      page_4 = create(:page, parent: page_3); page_4.revisions.first.update!(published: true)
      page_5 = create(:page, parent: page_3); page_5.revisions.first.update!(published: true)
      page_6 = create(:page, :blog         ); page_6.revisions.first.update!(published: true)

      page_3_published_revision = page_3.revisions.first
      page_3.revisions << build(:revision, :for_page) # Draft, shouldn't show up
      page_3.save!

      visit(root_path())

      main_menu    = find(:css, "nav.main_menu")
      main_content = find(:css, "section.main_content")

      expect(main_menu.find(:css, "h1")).to have_text(page_1.navigation_title)
      expect(main_content).to have_text(spechelp_strip_markup page_1.body)

      expect(main_menu).to     have_link(page_3.title, href: page_path(page_3.slug))
      expect(main_menu).to     have_link(page_6.title, href: page_path(page_6.slug))
      expect(main_menu).to_not have_link(page_1.title, href: page_path(page_1.slug)) # hidden
      expect(main_menu).to_not have_link(page_2.title, href: page_path(page_2.slug)) # draft-only
      expect(main_menu).to_not have_link(page_4.title, href: page_path(page_4.slug)) # child of 3
      expect(main_menu).to_not have_link(page_5.title, href: page_path(page_5.slug)) # also a child of 3

      # Note we check that the menu text shown for page 3 is from its published
      # revision, not its draft.
      #
      page_3_link = find(:css, "nav.main_menu a", text: page_3_published_revision.title)
      page_3_link.hover()

      expect(main_menu).to have_link(page_4.title, href: page_path(page_4.slug))
      expect(main_menu).to have_link(page_5.title, href: page_path(page_5.slug))

      main_menu.click_link(page_4.title)

      # Should be on the selected child page with its parent marked "current".
      #
      expect(page).to have_current_path(page_path(page_4.slug))
      expect(find(:css, "nav.main_menu li.current")).to have_link(page_3_published_revision.title)
    end

    it "does not show draft content or navigation titles" do
      p = create(:page) # (don't overwrite Capybara's "page" method!)

      published_revision = p.revisions.first; published_revision.update!(published: true)
      draft_revision     = build(:revision, :for_page, title: SecureRandom.uuid, body: SecureRandom.uuid, navigation_title: SecureRandom.uuid)

      p.revisions << draft_revision
      p.save!

      visit(page_path(p))

      expect(find(:css, "nav.main_menu h1"        )).to have_text(published_revision.navigation_title)
      expect(find(:css, "nav.main_menu li.current")).to have_text(published_revision.title)
      expect(find(:css, "section.main_content"    )).to have_text(spechelp_strip_markup published_revision.body)

      expect(page).to_not have_text(draft_revision.title)
      expect(page).to_not have_text(draft_revision.navigation_title)
      expect(page).to_not have_text(spechelp_strip_markup draft_revision.body)

      # Drafts don't show up even if someone tries to force the issue...
      #
      visit(page_path(p, revision: draft_revision.id))

      expect(page).to_not have_text(draft_revision.title)
      expect(page).to_not have_text(draft_revision.navigation_title)
      expect(page).to_not have_text(spechelp_strip_markup draft_revision.body)

      # ...you have to be going via the admin routes to do that.
      #
      spechelp_log_in()

      visit(admin_page_path(p, revision: draft_revision.id))

      expect(page).to have_text(draft_revision.title)
      expect(page).to have_text(draft_revision.navigation_title)
      expect(page).to have_text(spechelp_strip_markup draft_revision.body)
    end

    it "redirects to the Admin page if logged in" do
      p = create(:page)
      p.revisions.first.update!(published: true)

      visit(page_path(p.slug))
      expect(page).to have_current_path(page_path(p.slug)) # No redirection

      spechelp_log_in()

      visit(page_path(p.slug))
      expect(page).to have_current_path(admin_page_path(p.slug)) # Redirected to admin
    end
  end # 'context "navigation" do'

  context "header" do
    before :each do
      p = create(:page)
      p.revisions.first.update!(published: true)
    end

    context "with GOOGLE_AD_ID defined" do
      around :each do | example |
        old_value = ENV["GOOGLE_AD_ID"]
        ENV["GOOGLE_AD_ID"] = "XX-123456789-0"
        example.run()
      ensure
        ENV["GOOGLE_AD_ID"] = old_value
      end

      it "includes Google scripting" do
        visit(root_path())

        expect(page).to have_css('script[src*="www.googletagmanager.com"]', visible: :all) # (to match with "page does not have CSS" test below)
        expect(page).to have_css('script[src="https://www.googletagmanager.com/gtag/js?id=XX-123456789-0"]', visible: :all)
      end
    end # 'context "with GOOGLE_AD_ID defined" do'

    context "with GOOGLE_AD_ID undefined" do
      around :each do | example |
        old_value = ENV["GOOGLE_AD_ID"]
        ENV.delete("GOOGLE_AD_ID")
        example.run()
      ensure
        ENV["GOOGLE_AD_ID"] = old_value
      end

      it "omits Google scripting" do
        visit(root_path())

        expect(page).to_not have_css('script[src*="www.googletagmanager.com"]', visible: :all)
      end
    end # 'context "with GOOGLE_AD_ID undefined" do'
  end # 'context "header" do'

  context "footer" do
    before :each do
      create(:page)
      allow(Hcms.config).to receive(:hide_contact_info).and_return(false)
    end

    it "shows telephone and e-mail" do
      allow(Hcms.config).to receive(:contact_tel_human).and_return("0 345 678")
      allow(Hcms.config).to receive(:contact_tel_full ).and_return("+12 345 678")
      allow(Hcms.config).to receive(:contact_email    ).and_return("test@example.com")

      visit(root_path())
      cms_menu = find(:css, "footer section.footer_content nav.cms_menu")

      expect(cms_menu).to have_link("0 345 678",        href: "tel:+12 345 678")
      expect(cms_menu).to have_link("test@example.com", href: "mailto:test@example.com")
    end

    it "handles absent telephone and e-mail" do
      allow(Hcms.config).to receive(:contact_tel_human).and_return(nil)
      allow(Hcms.config).to receive(:contact_tel_full ).and_return("+12 345 678") # (sic.)
      allow(Hcms.config).to receive(:contact_email    ).and_return("")

      visit(root_path())
      cms_menu = find(:css, "footer section.footer_content nav.cms_menu")

      expect(cms_menu).to_not have_css("a")
    end

    it "shows social media" do
      allow(Hcms.config).to receive(:facebook ).and_return("facebook-href")
      allow(Hcms.config).to receive(:twitter  ).and_return("twitter-href")
      allow(Hcms.config).to receive(:instagram).and_return("instagram-href")

      visit(root_path())
      social_menu = find(:css, "footer section.footer_content nav.social_menu")

      expect(social_menu.find_link(href: "facebook-href" )).to have_css("i.fa.fa-facebook-official")
      expect(social_menu.find_link(href: "twitter-href"  )).to have_css("i.fa.fa-twitter-square")
      expect(social_menu.find_link(href: "instagram-href")).to have_css("i.fa.fa-instagram")
    end

    it "handles absent social media" do
      allow(Hcms.config).to receive(:facebook ).and_return("")
      allow(Hcms.config).to receive(:twitter  ).and_return(" ")
      allow(Hcms.config).to receive(:instagram).and_return(nil)

      visit(root_path())
      social_menu = find(:css, "footer section.footer_content nav.social_menu")

      expect(social_menu).to_not have_css("a")
    end

    it "shows the footer summary" do
      allow(Hcms.config).to receive(:footer_summary).and_return("Summary text")

      visit(root_path())

      expect(find(:css, "footer section.footer_suffix")).to have_text("Summary text")
    end

    it "handles an absent footer summary" do
      allow(Hcms.config).to receive(:footer_summary).and_return("")
      visit(root_path())

      expect(page).to_not have_css("footer section.footer_suffix")

      allow(Hcms.config).to receive(:footer_summary).and_return(nil)
      visit(root_path())

      expect(page).to_not have_css("footer section.footer_suffix")
    end

    context "when asked to hide telephone and e-mail" do
      before :each do
        allow(Hcms.config).to receive(:contact_tel_human).and_return("0 345 678")
        allow(Hcms.config).to receive(:contact_tel_full ).and_return("+12 345 678")
        allow(Hcms.config).to receive(:contact_email    ).and_return("test@example.com")

        allow(Hcms.config).to receive(:hide_contact_info).and_return(true)
      end

      it "shows nothing by default" do
        visit(root_path())
        cms_menu = find(:css, "footer section.footer_content nav.cms_menu")

        expect(cms_menu).to_not have_css("a")
      end

      it "shows a contact-us page link if there is one" do
        page_1 = create(:page,              ); page_1.revisions.first.update!(published: true)
        page_2 = create(:page, :contact_form); page_2.revisions.first.update!(published: true)
        page_3 = create(:page, :contact_form); page_3.revisions.first.update!(published: true)

        visit(root_path())
        cms_menu = find(:css, "footer section.footer_content nav.cms_menu")

        expect(cms_menu).to have_link("Contact us", href: page_path(page_2.slug))
      end
    end
  end # 'context "normal pages" do'

  context "contact forms" do
    around :each do | example |
      old_country_code = Phonelib.default_country
      Phonelib.default_country = "NZ"
      example.run()
    ensure
      Phonelib.default_country = old_country_code
    end

    before :each do
      allow_any_instance_of(ActionView::Base).to receive(:recaptcha_v3).and_return("")

      allow(Hcms.config).to receive(:contact_email).and_return("contact@example.com")
      allow(Hcms.config).to receive(:site_name    ).and_return("Site Under Test")
    end

    it "display, validate and submit (no menu)" do
      p = create(:page, :contact_form)
      p.revisions.first.update!(published: true)

      visit page_path(p)

      expect(page).to have_field("forms_contact_name")
      expect(page).to have_field("forms_contact_email")
      expect(page).to have_field("forms_contact_phone")
      expect(page).to have_field("forms_contact_message")

      click_on("Send message")

      expect(page).to have_css("div.field_error_messages", text: "Name must be provided")
      expect(page).to have_css("div.field_error_messages", text: "E-mail address must be provided")
      expect(page).to have_css("div.field_error_messages", text: "Message must be provided")

      fill_in("forms_contact_phone", with: "123")
      click_on("Send message")

      expect(page).to have_css("div.field_error_messages", text: "Telephone number format not recognised")

      fill_in("forms_contact_phone", with: "021 000 000") # Given enforced NZ dial prefix, that's reasonable...
      click_on("Send message")

      expect(page).to_not have_css("div.field_error_messages", text: "Telephone number format not recognised")

      fill_in("forms_contact_phone", with: "07855 000 000") # ...but this is not, as that's UK format (+44)
      click_on("Send message")

      expect(page).to have_css("div.field_error_messages", text: "Telephone number format not recognised")

      fill_in("forms_contact_name",    with: "Fred Flintstone")
      fill_in("forms_contact_email",   with: "fred@example.com")
      fill_in("forms_contact_phone",   with: "+64 21 000 000")
      fill_in("forms_contact_message", with: "Quick Brown Fox\nOther text")

      click_on("Send message")
      spechelp_check_flash(:notice, "Your message has been sent")

      delivered = spechelp_decode_multipart()

      expect(delivered.email.from   ).to eql(["contact@example.com"])
      expect(delivered.email.to     ).to eql(["contact@example.com"])
      expect(delivered.email.subject).to eql("[Site Under Test] \"#{p.title}\" - message")

      expect(delivered.text).to include("Fred Flintstone")
      expect(delivered.text).to include("fred@example.com")
      expect(delivered.text).to include("+64 21 000 000")
      expect(delivered.text).to include("Quick Brown Fox\nOther text")

      expect(delivered.html).to have_css("dd", text: "Fred Flintstone")
      spechelp_check_mailto(
        html:    delivered.html,
        email:   "fred@example.com",
        body:    "You asked:\n\n> Quick Brown Fox\n> Other text\n\n",
        subject: "Your Site Under Test enquiry"
      )
      spechelp_check_tel(
        html:  delivered.html,
        phone: "+64 21 000 000"
      )
      expect(delivered.html).to include(">Quick Brown Fox\n<br>Other text</p>")
    end

    it "are OK with no phone number" do
      p = create(:page, :contact_form)
      p.revisions.first.update!(published: true)

      visit page_path(p)

      fill_in("forms_contact_name",    with: "Fred Flintstone")
      fill_in("forms_contact_email",   with: "fred@example.com")
      fill_in("forms_contact_message", with: "Quick Brown Fox")

      click_on("Send message")
      spechelp_check_flash(:notice, "Your message has been sent")

      delivered = spechelp_decode_multipart()

      expect(delivered.email.from   ).to eql(["contact@example.com"])
      expect(delivered.email.to     ).to eql(["contact@example.com"])
      expect(delivered.email.subject).to eql("[Site Under Test] \"#{p.title}\" - message")

      expect(delivered.text).to include("Fred Flintstone")
      expect(delivered.text).to include("fred@example.com")
      expect(delivered.text).to include("Quick Brown Fox")

      expect(delivered.html).to have_css("dd", text: "Fred Flintstone")
      spechelp_check_mailto(
        html:    delivered.html,
        email:   "fred@example.com",
        body:    "You asked:\n\n> Quick Brown Fox\n\n",
        subject: "Your Site Under Test enquiry"
      )
      expect(delivered.html).to include(">Quick Brown Fox</p>")
    end

    it "support a menu with a default label" do
      p = create(
        :page,
        :contact_form,
        form_selection_list_contents: "One\nThis is item two\nThree"
      )
      p.revisions.first.update!(published: true)

      visit page_path(p)

      fill_in("forms_contact_name",    with: "Fred Flintstone")
      fill_in("forms_contact_email",   with: "fred@example.com")
      fill_in("forms_contact_message", with: "Quick Brown Fox")

      select("This is item two", from: "forms_contact_menu_selection")

      click_on("Send message")
      spechelp_check_flash(:notice, "Your message has been sent")

      delivered = spechelp_decode_multipart()

      expect(delivered.email.from   ).to eql(["contact@example.com"])
      expect(delivered.email.to     ).to eql(["contact@example.com"])
      expect(delivered.email.subject).to eql("[Site Under Test] \"#{p.title}\" - message")

      expect(delivered.text).to include("Menu selection")
      expect(delivered.text).to include("This is item two")
      expect(delivered.text).to include("Fred Flintstone")
      expect(delivered.text).to include("fred@example.com")
      expect(delivered.text).to include("Quick Brown Fox")

      expect(delivered.html).to have_css("dt", text: "Menu selection")
      expect(delivered.html).to have_css("dd", text: "This is item two")
      expect(delivered.html).to have_css("dd", text: "Fred Flintstone")
      spechelp_check_mailto(
        html:    delivered.html,
        email:   "fred@example.com",
        body:    "You asked:\n\n> Quick Brown Fox\n\n",
        subject: "Your Site Under Test enquiry"
      )
      expect(delivered.html).to include(">Quick Brown Fox</p>")
    end

    it "support a menu with a custom label" do
      p = create(
        :page,
        :contact_form,
        form_selection_list_label:    "How did you hear about us?",
        form_selection_list_contents: "One\nThis is item two\nThree"
      )
      p.revisions.first.update!(published: true)

      visit page_path(p)

      fill_in("forms_contact_name",    with: "Fred Flintstone")
      fill_in("forms_contact_email",   with: "fred@example.com")
      fill_in("forms_contact_message", with: "Quick Brown Fox")

      select("This is item two", from: "forms_contact_menu_selection")

      click_on("Send message")
      spechelp_check_flash(:notice, "Your message has been sent")

      delivered = spechelp_decode_multipart()

      expect(delivered.email.from   ).to eql(["contact@example.com"])
      expect(delivered.email.to     ).to eql(["contact@example.com"])
      expect(delivered.email.subject).to eql("[Site Under Test] \"#{p.title}\" - message")

      expect(delivered.text).to include("How did you hear about us?")
      expect(delivered.text).to include("This is item two")
      expect(delivered.text).to include("Fred Flintstone")
      expect(delivered.text).to include("fred@example.com")
      expect(delivered.text).to include("Quick Brown Fox")

      expect(delivered.html).to have_css("dt", text: "How did you hear about us?")
      expect(delivered.html).to have_css("dd", text: "This is item two")
      expect(delivered.html).to have_css("dd", text: "Fred Flintstone")
      spechelp_check_mailto(
        html:    delivered.html,
        email:   "fred@example.com",
        body:    "You asked:\n\n> Quick Brown Fox\n\n",
        subject: "Your Site Under Test enquiry"
      )
      expect(delivered.html).to include(">Quick Brown Fox</p>")
    end
  end # 'context "contact forms" do'

  context "booking forms" do
    around :each do | example |
      old_country_code = Phonelib.default_country
      Phonelib.default_country = "NZ"
      example.run()
    ensure
      Phonelib.default_country = old_country_code
    end

    before :each do
      allow_any_instance_of(ActionView::Base).to receive(:recaptcha_v3).and_return("")

      allow(Hcms.config).to receive(:hide_booking_date).and_return(false)
      allow(Hcms.config).to receive(:booking_email    ).and_return("booking@example.com")
      allow(Hcms.config).to receive(:site_name        ).and_return("Site Under Test")
    end

    it "display, validate and submit (no menu)" do
      p = create(:page, :booking_form)
      p.revisions.first.update!(published: true)

      visit page_path(p)

      expect(page).to have_field("forms_booking_name")
      expect(page).to have_field("forms_booking_email")
      expect(page).to have_field("forms_booking_phone")
      expect(page).to have_field("forms_booking_date")
      expect(page).to have_field("forms_booking_time")
      expect(page).to have_field("forms_booking_notes")

      click_on("Send enquiry")

      expect(page).to have_css("div.field_error_messages", text: "Name must be provided")
      expect(page).to have_css("div.field_error_messages", text: "E-mail address must be provided")

      fill_in("forms_booking_phone", with: "123")
      click_on("Send enquiry")

      expect(page).to have_css("div.field_error_messages", text: "Telephone number format not recognised")

      fill_in("forms_booking_phone", with: "021 000 000") # Given enforced NZ dial prefix, that's reasonable...
      click_on("Send enquiry")

      expect(page).to_not have_css("div.field_error_messages", text: "Telephone number format not recognised")

      fill_in("forms_booking_phone", with: "07855 000 000") # ...but this is not, as that's UK format (+44)
      click_on("Send enquiry")

      expect(page).to have_css("div.field_error_messages", text: "Telephone number format not recognised")

      fill_in("forms_booking_name",  with: "Fred Flintstone")
      fill_in("forms_booking_email", with: "fred@example.com")
      fill_in("forms_booking_phone", with: "+64 021 000 000") # (note intentional "+64 0...", which should be accepted)
      fill_in("forms_booking_date",  with: "20/01/#{Date.today.year + 2}")
      fill_in("forms_booking_time",  with: "11:30")
      fill_in("forms_booking_notes", with: "Quick Brown Fox\nOther text")

      click_on("Send enquiry")
      spechelp_check_flash(:notice, "Your booking enquiry has been sent")

      delivered = spechelp_decode_multipart()

      expect(delivered.email.from   ).to eql(["booking@example.com"])
      expect(delivered.email.to     ).to eql(["booking@example.com"])
      expect(delivered.email.subject).to eql("[Site Under Test] \"#{p.title}\" - booking enquiry")

      expect(delivered.text).to include("Fred Flintstone")
      expect(delivered.text).to include("fred@example.com")
      expect(delivered.text).to include("+64 021 000 000")
      expect(delivered.text).to include("20/01/#{Date.today.year + 2}")
      expect(delivered.text).to include("11:30")
      expect(delivered.text).to include("Quick Brown Fox\nOther text")

      expect(delivered.html).to have_css("dd", text: "Fred Flintstone")
      spechelp_check_mailto(
        html:    delivered.html,
        email:   "fred@example.com",
        subject: "Your Site Under Test booking enquiry"
      )
      spechelp_check_tel(
        html:  delivered.html,
        phone: '+64 021 000 000'
      )
      expect(delivered.html).to have_css("dt", text: "Date")
      expect(delivered.html).to have_css("dd", text: "20/01/#{Date.today.year + 2}")
      expect(delivered.html).to have_css("dt", text: "Preferred time")
      expect(delivered.html).to have_css("dd", text: "11:30")
      expect(delivered.html).to include(">Quick Brown Fox\n<br>Other text</p>")
    end

    it "are OK with no phone number, date or time" do
      p = create(:page, :booking_form)
      p.revisions.first.update!(published: true)

      visit page_path(p)

      fill_in("forms_booking_name",  with: "Fred Flintstone")
      fill_in("forms_booking_email", with: "fred@example.com")
      fill_in("forms_booking_notes", with: "Quick Brown Fox")

      click_on("Send enquiry")
      spechelp_check_flash(:notice, "Your booking enquiry has been sent")

      delivered = spechelp_decode_multipart()

      expect(delivered.email.from   ).to eql(["booking@example.com"])
      expect(delivered.email.to     ).to eql(["booking@example.com"])
      expect(delivered.email.subject).to eql("[Site Under Test] \"#{p.title}\" - booking enquiry")

      expect(delivered.text).to include("Fred Flintstone")
      expect(delivered.text).to include("fred@example.com")
      expect(delivered.text).to include("Quick Brown Fox")

      expect(delivered.html).to have_css("dd", text: "Fred Flintstone")
      spechelp_check_mailto(
        html:    delivered.html,
        email:   "fred@example.com",
        subject: "Your Site Under Test booking enquiry"
      )
      expect(delivered.html).to include(">Quick Brown Fox</p>")
    end

    it "support a menu with a default label" do
      p = create(
        :page,
        :booking_form,
        form_selection_list_contents: "One\nThis is item two\nThree"
      )
      p.revisions.first.update!(published: true)

      visit page_path(p)

      fill_in("forms_booking_name",  with: "Fred Flintstone")
      fill_in("forms_booking_email", with: "fred@example.com")
      fill_in("forms_booking_notes", with: "Quick Brown Fox")

      select("This is item two", from: "forms_booking_menu_selection")

      click_on("Send enquiry")
      spechelp_check_flash(:notice, "Your booking enquiry has been sent")

      delivered = spechelp_decode_multipart()

      expect(delivered.email.from   ).to eql(["booking@example.com"])
      expect(delivered.email.to     ).to eql(["booking@example.com"])
      expect(delivered.email.subject).to eql("[Site Under Test] \"#{p.title}\" - booking enquiry")

      expect(delivered.text).to include("Menu selection")
      expect(delivered.text).to include("This is item two")
      expect(delivered.text).to include("Fred Flintstone")
      expect(delivered.text).to include("fred@example.com")
      expect(delivered.text).to include("Quick Brown Fox")

      expect(delivered.html).to have_css("dt", text: "Menu selection")
      expect(delivered.html).to have_css("dd", text: "This is item two")
      expect(delivered.html).to have_css("dd", text: "Fred Flintstone")
      spechelp_check_mailto(
        html:    delivered.html,
        email:   "fred@example.com",
        subject: "Your Site Under Test booking enquiry"
      )
      expect(delivered.html).to include(">Quick Brown Fox</p>")
    end

    it "support a menu with a custom label" do
      p = create(
        :page,
        :booking_form,
        form_selection_list_label:    "How did you hear about us?",
        form_selection_list_contents: "One\nThis is item two\nThree"
      )
      p.revisions.first.update!(published: true)

      visit page_path(p)

      fill_in("forms_booking_name",  with: "Fred Flintstone")
      fill_in("forms_booking_email", with: "fred@example.com")
      fill_in("forms_booking_notes", with: "Quick Brown Fox")

      select("This is item two", from: "forms_booking_menu_selection")

      click_on("Send enquiry")
      spechelp_check_flash(:notice, "Your booking enquiry has been sent")

      delivered = spechelp_decode_multipart()

      expect(delivered.email.from   ).to eql(["booking@example.com"])
      expect(delivered.email.to     ).to eql(["booking@example.com"])
      expect(delivered.email.subject).to eql("[Site Under Test] \"#{p.title}\" - booking enquiry")

      expect(delivered.text).to include("How did you hear about us?")
      expect(delivered.text).to include("This is item two")
      expect(delivered.text).to include("Fred Flintstone")
      expect(delivered.text).to include("fred@example.com")
      expect(delivered.text).to include("Quick Brown Fox")

      expect(delivered.html).to have_css("dt", text: "How did you hear about us?")
      expect(delivered.html).to have_css("dd", text: "This is item two")
      expect(delivered.html).to have_css("dd", text: "Fred Flintstone")
      spechelp_check_mailto(
        html:    delivered.html,
        email:   "fred@example.com",
        subject: "Your Site Under Test booking enquiry"
      )
      expect(delivered.html).to include(">Quick Brown Fox</p>")
    end

    it "obey the hide-date/time setting" do
      p = create(
        :page,
        :booking_form,
        hide_date_and_time:           true,
        form_selection_list_label:    "How did you hear about us?",
        form_selection_list_contents: "One\nThis is item two\nThree"
      )
      p.revisions.first.update!(published: true)

      visit page_path(p)

      expect(page).to     have_field("forms_booking_name")
      expect(page).to     have_field("forms_booking_email")
      expect(page).to     have_field("forms_booking_phone")
      expect(page).to_not have_field("forms_booking_date")
      expect(page).to_not have_field("forms_booking_time")
      expect(page).to     have_field("forms_booking_notes")

      fill_in("forms_booking_name",  with: "Fred Flintstone")
      fill_in("forms_booking_email", with: "fred@example.com")
      fill_in("forms_booking_notes", with: "Quick Brown Fox")

      select("This is item two", from: "forms_booking_menu_selection")

      click_on("Send enquiry")
      spechelp_check_flash(:notice, "Your booking enquiry has been sent")

      delivered = spechelp_decode_multipart()

      expect(delivered.email.from   ).to eql(["booking@example.com"])
      expect(delivered.email.to     ).to eql(["booking@example.com"])
      expect(delivered.email.subject).to eql("[Site Under Test] \"#{p.title}\" - booking enquiry")

      expect(delivered.text).to include("How did you hear about us?")
      expect(delivered.text).to include("This is item two")
      expect(delivered.text).to include("Fred Flintstone")
      expect(delivered.text).to include("fred@example.com")
      expect(delivered.text).to include("Quick Brown Fox")

      expect(delivered.html).to have_css('dd', text: 'Fred Flintstone')
      spechelp_check_mailto(
        html:    delivered.html,
        email:   "fred@example.com",
        subject: "Your Site Under Test booking enquiry"
      )
      expect(delivered.html).to     have_css("dt", text: "How did you hear about us?")
      expect(delivered.html).to     have_css("dd", text: "This is item two")
      expect(delivered.html).to_not have_css("dt", text: "Date")
      expect(delivered.html).to_not have_css("dt", text: "Preferred time")
      expect(delivered.html).to     include(">Quick Brown Fox</p>")
     end
  end # 'context "booking forms" do'

  context "blog containers" do
    # Nothing to do here; it's all in 'articles_spec.rb'
  end # 'context "blog containers" do'

  context "event containers" do
    # Nothing to do here; it's all in 'events_spec.rb'
  end # 'context "event containers" do'

  context "shared" do
    let(:path_to_test) { root_path() }

    context "normal page" do
      before :each do
        p = create(:page)
        p.revisions.first.update!(published: true)
      end

      it_behaves_like "a public page footer"
    end # 'context "normal page" do'

    context "contact form" do
      before :each do
        expect_any_instance_of(ActionView::Base).to receive(:recaptcha_v3).and_return('')

        p = create(:page, :contact_form)
        p.revisions.first.update!(published: true)
      end # 'context "booking form" do'

      it_behaves_like "a public page footer"
    end # 'context "contact form" do'

    context "booking form" do
      before :each do
        expect_any_instance_of(ActionView::Base).to receive(:recaptcha_v3).and_return('')

        p = create(:page, :booking_form)
        p.revisions.first.update!(published: true)
      end # 'context "booking form" do'

      it_behaves_like "a public page footer"
    end

    context "blog container" do
      # Nothing to do here; it's all in 'articles_spec.rb'
    end # 'context "blog container" do'

    context "event container" do
      # Nothing to do here; it's all in 'events_spec.rb'
    end # 'context "event container" do'
  end # 'context "shared" do'
end

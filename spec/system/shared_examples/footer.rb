RSpec.shared_examples "a public page footer" do
  before :each do
    allow(Hcms.config).to receive(:hide_contact_info).and_return(false)
  end

  it "shows telephone and e-mail" do
    allow(Hcms.config).to receive(:contact_tel_human).and_return("0 345 678")
    allow(Hcms.config).to receive(:contact_tel_full ).and_return("+12 345 678")
    allow(Hcms.config).to receive(:contact_email    ).and_return("test@example.com")

    visit(path_to_test())
    cms_menu = find(:css, "footer section.footer_content nav.cms_menu")

    expect(cms_menu).to have_link("0 345 678",        href: "tel:+12 345 678")
    expect(cms_menu).to have_link("test@example.com", href: "mailto:test@example.com")
  end

  it "handles absent telephone and e-mail" do
    allow(Hcms.config).to receive(:contact_tel_human).and_return(nil)
    allow(Hcms.config).to receive(:contact_tel_full ).and_return("+12 345 678") # (sic.)
    allow(Hcms.config).to receive(:contact_email    ).and_return("")

    visit(path_to_test())
    cms_menu = find(:css, "footer section.footer_content nav.cms_menu")

    expect(cms_menu).to_not have_css("a")
  end

  it "shows social media" do
    allow(Hcms.config).to receive(:facebook ).and_return("facebook-href")
    allow(Hcms.config).to receive(:twitter  ).and_return("twitter-href")
    allow(Hcms.config).to receive(:instagram).and_return("instagram-href")

    visit(path_to_test())
    social_menu = find(:css, "footer section.footer_content nav.social_menu")

    expect(social_menu.find_link(href: "facebook-href" )).to have_css("i.fa.fa-facebook-official")
    expect(social_menu.find_link(href: "twitter-href"  )).to have_css("i.fa.fa-twitter-square")
    expect(social_menu.find_link(href: "instagram-href")).to have_css("i.fa.fa-instagram")
  end

  it "handles absent social media" do
    allow(Hcms.config).to receive(:facebook ).and_return("")
    allow(Hcms.config).to receive(:twitter  ).and_return(" ")
    allow(Hcms.config).to receive(:instagram).and_return(nil)

    visit(path_to_test())
    social_menu = find(:css, "footer section.footer_content nav.social_menu")

    expect(social_menu).to_not have_css("a")
  end

  it "shows the footer summary" do
    allow(Hcms.config).to receive(:footer_summary).and_return("Summary text")

    visit(path_to_test())

    expect(find(:css, "footer section.footer_suffix")).to have_text("Summary text")
  end

  it "handles an absent footer summary" do
    allow(Hcms.config).to receive(:footer_summary).and_return("")
    visit(path_to_test())

    expect(page).to_not have_css("footer section.footer_suffix")

    allow(Hcms.config).to receive(:footer_summary).and_return(nil)
    visit(path_to_test())

    expect(page).to_not have_css("footer section.footer_suffix")
  end

  context "when asked to hide telephone and e-mail", if: Page.where(page_type: Page::PAGE_TYPE_CONTACT_FORM).none? do
    before :each do
      allow(Hcms.config).to receive(:contact_tel_human).and_return("0 345 678")
      allow(Hcms.config).to receive(:contact_tel_full ).and_return("+12 345 678")
      allow(Hcms.config).to receive(:contact_email    ).and_return("test@example.com")

      allow(Hcms.config).to receive(:hide_contact_info).and_return(true)
    end

    # Can't really do these if there is an existing contact form, since that
    # would be the thing likely to appear in the footer.
    #
    it "shows nothing by default" do
      have_any_already = Page.where(page_type: Page::PAGE_TYPE_CONTACT_FORM).any?

      visit(path_to_test())
      cms_menu = find(:css, "footer section.footer_content nav.cms_menu")

      unless have_any_already
        expect(cms_menu).to_not have_css("a")
      end
    end

    it "shows a contact-us page link if there is one" do
      have_any_already = Page.where(page_type: Page::PAGE_TYPE_CONTACT_FORM).any?

      page_1 = create(:page,              ); page_1.revisions.first.update!(published: true)
      page_2 = create(:page, :contact_form); page_2.revisions.first.update!(published: true)
      page_3 = create(:page, :contact_form); page_3.revisions.first.update!(published: true)

      visit(path_to_test())
      cms_menu = find(:css, "footer section.footer_content nav.cms_menu")

      unless have_any_already
        expect(cms_menu).to have_link("Contact us", href: page_path(page_2.slug))
      end
    end
  end # 'context "when asked to hide telephone and e-mail" do'
end

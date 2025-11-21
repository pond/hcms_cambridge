require "spec_helper.rb"

RSpec.describe Page, type: :model do
  it "is an Editable" do # (because that's tested separately, so no need to duplicate tests here)
    expect(Page.ancestors).to include(Editable)
  end

  context "scopes and associations" do
    it "default scope orders by-list-position ascending" do
      page_1 = create(:page, position: 3)
      page_2 = create(:page, position: 1)
      page_3 = create(:page, position: 2)

      expect(Page.all.to_a).to eql([page_2, page_3, page_1])
    end

    it "parent/child" do
      parent  = create(:page)
      child_1 = create(:page, parent: parent)
      child_2 = create(:page, parent: parent)

      expect(parent.parent  ).to be_nil
      expect(parent.children).to match_array([child_1, child_2])

      expect(child_1.parent  ).to eql(parent)
      expect(child_2.parent  ).to eql(parent)
      expect(child_1.children).to be_empty
      expect(child_2.children).to be_empty
    end

    it "::top_level omits child pages" do
      parent  = create(:page)
      child_1 = create(:page, parent: parent)
      child_2 = create(:page, parent: parent)

      expect(Page.top_level).to match_array([parent])
    end

    it "::top_level_except omits child pages and given IDs" do
      parent_1 = create(:page)
      parent_2 = create(:page)
      parent_3 = create(:page)
      parent_4 = create(:page)
      child_1  = create(:page, parent: parent_1)
      child_2  = create(:page, parent: parent_1)

      expect(Page.top_level_except(parent_2.id             )).to match_array([parent_1, parent_3, parent_4])
      expect(Page.top_level_except(parent_2.id, parent_3.id)).to match_array([parent_1, parent_4])
    end

    it "::for_navigation only includes published, not-hidden pages" do
      page_1 = create(:page, hidden: false); page_1.revisions.update_all(published: false)
      page_2 = create(:page, hidden: false); page_2.revisions.update_all(published: true)
      page_3 = create(:page, hidden: false); page_3.revisions.update_all(published: true)
      page_4 = create(:page, hidden: true ); page_4.revisions.update_all(published: true)

      expect(Page.for_navigation).to match_array([page_2, page_3])
    end

    it "::home returns the oldest top-level page" do
      expect(Page.home).to be_nil

      parent_1 = create(:page, created_at: Time.now + 1.day)
      parent_2 = create(:page, created_at: Time.now - 1.day)
      parent_3 = create(:page, created_at: Time.now)
      child_1  = create(:page, parent: parent_2, created_at: Time.now - 2.days)
      child_2  = create(:page, parent: parent_2, created_at: Time.now + 2.days)

      expect(Page.home).to eql(parent_2)
    end
  end # 'context "scopes and associations" do'

  context "page types" do
    context "normal" do
      it "responds correctly to trait enquiries" do
        page = build(:page, page_type: Page::PAGE_TYPE_NORMAL)

        # Overriding Editable
        #
        expect(page.is_normal_type?).to eql(true)
        expect(page.is_form_type?  ).to eql(false)
        expect(page.is_blog_type?  ).to eql(false)
        expect(page.is_events_type?).to eql(false)
        expect(page.is_article?    ).to eql(false)
        expect(page.is_event?      ).to eql(false)

        # Specific to Page
        #
        expect(page.is_contact_form?).to eql(false)
        expect(page.is_booking_form?).to eql(false)
      end

      it "requires body text via revisions" do
        page = build(:page, page_type: Page::PAGE_TYPE_NORMAL)

        expect(page).to be_valid

        page.revisions.first.body = nil

        expect(page).to_not be_valid
        expect(page.errors.of_kind?(:body, :blank)).to eql(true)
      end
    end # 'context "normal" do'

    context "contact form" do
      it "responds correctly to trait enquiries" do
        page = build(:page, :contact_form)

        # Overriding Editable
        #
        expect(page.is_normal_type?).to eql(false)
        expect(page.is_form_type?  ).to eql(true)
        expect(page.is_blog_type?  ).to eql(false)
        expect(page.is_events_type?).to eql(false)
        expect(page.is_article?    ).to eql(false)
        expect(page.is_event?      ).to eql(false)

        # Specific to Page
        #
        expect(page.is_contact_form?).to eql(true)
        expect(page.is_booking_form?).to eql(false)
      end

      it "requires body text via revisions" do
        page = build(:page, :contact_form)

        expect(page).to be_valid

        page.revisions.first.body = nil

        expect(page).to_not be_valid
        expect(page.errors.of_kind?(:body, :blank)).to eql(true)
      end
    end # 'context "contact form" do'

    context "booking form" do
      it "responds correctly to trait enquiries" do
        page = build(:page, :booking_form)

        # Overriding Editable
        #
        expect(page.is_normal_type?).to eql(false)
        expect(page.is_form_type?  ).to eql(true)
        expect(page.is_blog_type?  ).to eql(false)
        expect(page.is_events_type?).to eql(false)
        expect(page.is_article?    ).to eql(false)
        expect(page.is_event?      ).to eql(false)

        # Specific to Page
        #
        expect(page.is_contact_form?).to eql(false)
        expect(page.is_booking_form?).to eql(true)
      end

      it "requires body text via revisions" do
        page = build(:page, :booking_form)

        expect(page).to be_valid

        page.revisions.first.body = nil

        expect(page).to_not be_valid
        expect(page.errors.of_kind?(:body, :blank)).to eql(true)
      end
    end # 'context "booking form" do'

    context "blog" do
      it "responds correctly to trait enquiries" do
        page = build(:page, :blog)

        # Overriding Editable
        #
        expect(page.is_normal_type?).to eql(false)
        expect(page.is_form_type?  ).to eql(false)
        expect(page.is_blog_type?  ).to eql(true)
        expect(page.is_events_type?).to eql(false)
        expect(page.is_article?    ).to eql(false)
        expect(page.is_event?      ).to eql(false)

        # Specific to Page
        #
        expect(page.is_contact_form?).to eql(false)
        expect(page.is_booking_form?).to eql(false)
      end

      it "does not require body" do
        page = build(:page, :blog)

        expect(page).to be_valid

        page.revisions.first.body = nil

        expect(page).to be_valid
      end
    end # 'context "blog" do'

    context "events" do
      it "responds correctly to trait enquiries" do
        page = build(:page, :events)

        # Overriding Editable
        #
        expect(page.is_normal_type?).to eql(false)
        expect(page.is_form_type?  ).to eql(false)
        expect(page.is_blog_type?  ).to eql(false)
        expect(page.is_events_type?).to eql(true)
        expect(page.is_article?    ).to eql(false)
        expect(page.is_event?      ).to eql(false)

        # Specific to Page
        #
        expect(page.is_contact_form?).to eql(false)
        expect(page.is_booking_form?).to eql(false)
      end

      it "does not require body" do
        page = build(:page, :events)

        expect(page).to be_valid

        page.revisions.first.body = nil

        expect(page).to be_valid
      end
    end # 'context "events" do'
  end # 'context "page types" do'

  context "utilities" do
    context "#for_navigation?" do
      it "returns 'true' for a not-hidden page with a published revision" do
        page_1 = create(:page, hidden: false); page_1.revisions.update_all(published: false)
        page_2 = create(:page, hidden: false); page_2.revisions.update_all(published: true)
        page_3 = create(:page, hidden: false); page_3.revisions.update_all(published: true)
        page_4 = create(:page, hidden: true ); page_4.revisions.update_all(published: true)

        expect(page_1.for_navigation?).to eql(false)
        expect(page_2.for_navigation?).to eql(true)
        expect(page_3.for_navigation?).to eql(true)
        expect(page_4.for_navigation?).to eql(false)
      end
    end # 'context "#for_navigation?" do'

    context "#form_class" do
      it "for a contact form" do
        page = build(:page, :contact_form)

        expect(page.form_class).to eql(Forms::Contact)
      end

      it "for a booking form" do
        page = build(:page, :booking_form)

        expect(page.form_class).to eql(Forms::Booking)
      end

      it "for other page types" do
        page = build(:page)

        expect(page.form_class).to be_nil

        page = build(:page, :blog)

        expect(page.form_class).to be_nil
      end
    end # 'context "#form_class" do'
  end # 'context "utilities" do'
end

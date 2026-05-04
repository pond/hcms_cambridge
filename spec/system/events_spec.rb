require "spec_helper.rb"
require_relative "shared_examples/footer.rb"

RSpec.describe "Events" do
  before :each do
    @page = create(:page, :events)
    @page.revisions.first.update!(published: true)
  end

  it "lists in starts-at ascending order and links to the events" do
    p       = create(:page, :events); p.revisions.first.update!(published: true) # ...so it'll be in the menu bar
    event_1 = create(:event, page: p); event_1.revisions.first.update!(published: true) # NOTE: Newer
    event_2 = create(:event, page: p); event_2.revisions.first.update!(published: true) # NOTE: Older

    event_1.update(starts_at: Time.now + 1.day, ends_at: (Time.now + 1.day) + 2.hours)
    event_2.update(starts_at: Time.now - 1.day, ends_at: (Time.now - 1.day) + 2.hours)

    visit page_path(p)

    expect(find(:css, "section.events article:nth-child(1)")).to have_text(event_1.title)
    expect(find(:css, "section.events article:nth-child(2)")).to have_text(event_2.title)

    # Event main page is highlighted as current item in navigation.
    #
    expect(find(:css, "nav.main_menu li.current")).to have_link(p.title)

    find(:css, "section.events article:nth-child(1)").click_on(event_1.title)

    expect(page).to have_current_path(page_event_path(page_id: p.slug, id: event_1.slug))

    # Title, summary and body but no hero image in the main event article.
    #
    expect(page).to     have_text(event_1.title)
    expect(page).to     have_text(event_1.summary)
    expect(page).to     have_text(spechelp_strip_markup event_1.body)
    expect(page).to_not have_css("img.event-hero-image[alt=\"#{event_1.title}\"]")

    # Event main page is still highlighted as current item in navigation.
    #
    expect(find(:css, "nav.main_menu li.current")).to have_link(p.title)
  end

  it "does not show drafts" do
    p       = create(:page, :events)
    event_1 = create(:event, page: p) # Note, not published
    event_2 = create(:event, page: p) # Same

    visit page_path(p)

    expect(page).to     have_text("There are no events scheduled")
    expect(page).to_not have_text(event_1.title)
    expect(page).to_not have_text(event_2.title)

    event_1.revisions.first.update!(published: true)
    event_2.revisions.first.update!(published: true)

    event_2_published_revision = event_2.revisions.first
    event_2_draft_revision     = build(:revision, :for_event) # Draft, shouldn't show up
    event_2.revisions << event_2_draft_revision
    event_2.save!

    visit page_path(p)

    expect(page).to_not have_text("There are no events scheduled")

    expect(page).to     have_text(event_1.title)
    expect(page).to     have_text(event_1.summary)
    expect(page).to_not have_text(spechelp_strip_markup event_1.body)
    expect(page).to     have_css("img.event-hero-image[alt=\"#{event_1.title}\"]")

    expect(page).to     have_text(event_2_published_revision.title)
    expect(page).to     have_text(event_2_published_revision.summary)
    expect(page).to_not have_text(spechelp_strip_markup event_2.body)
    expect(page).to     have_css("img.event-hero-image[alt=\"#{event_2_published_revision.title}\"]")

    expect(page).to_not have_text(event_2_draft_revision.title)
    expect(page).to_not have_text(event_2_draft_revision.summary)
    expect(page).to_not have_css("img.event-hero-image[alt=\"#{event_2_draft_revision.title}\"]")
  end

  context "navigation" do
    it "redirects to the Admin page if logged in" do
      p = create(:page, :events)
      p.revisions.first.update!(published: true)

      event = create(:event, page: p)
      event.revisions.first.update!(published: true)

      visit(page_path(p.slug))
      expect(page).to have_current_path(page_path(p.slug)) # No redirection

      visit(page_event_path(p.slug, event.slug))
      expect(page).to have_current_path(page_event_path(p.slug, event.slug)) # No redirection

      spechelp_log_in()

      visit(page_path(p.slug))
      expect(page).to have_current_path(admin_page_path(p.slug)) # Redirected to admin

      visit(page_event_path(p.slug, event.slug))
      expect(page).to have_current_path(admin_page_event_path(p.slug, event.slug)) # Redirected to admin
    end
  end # 'context "navigation" do'

  context "shared" do
    let(:path_to_test) { root_path() }

    before :each do
      @event = create(:event, page: @page)
      @event.revisions.first.update!(published: true)
    end

    context "when viewing the blog container" do
      let(:path_to_test) { page_path(@page.slug) }
      it_behaves_like "a public page footer"
    end

    context "when viewing an event" do
      let(:path_to_test) { page_event_path(@page.slug, @event.slug) }
      it_behaves_like "a public page footer"
    end
  end # 'context "shared" do'

  context "hidden events" do
    before :each do
      @event = create(:event, page: @page)
    end

    it 'drafts are not listed' do
      visit page_path(@page.slug)

      expect(page).to have_text("There are no events scheduled")
    end

    it 'published events are listed' do
      @event.revisions.first.update!(published: true)
      visit page_path(@page.slug)

      expect(page).to_not have_text("There are no events scheduled")
    end

    it 'hidden events are not listed' do
      @event.revisions.first.update!(published: true)
      @event.update!(hidden: true)
      visit page_path(@page.slug)

      expect(page).to have_text("There are no events scheduled")
    end

    it 'can be visited directly' do
      @event.revisions.first.update!(published: true)
      @event.update!(hidden: true)
      visit page_event_path(@page.slug, @event.slug)

      expect(page).to have_current_path(page_event_path(@page.slug, @event.slug))
      expect(page).to have_text(@event.title)
      expect(page).to have_text(@event.summary)
      expect(page).to have_text(spechelp_strip_markup @event.body)
    end
  end # 'context "hidden events" do'

  context "states" do
    before :each do
      @event = create(:event, page: @page)
      @event.revisions.first.update!(published: true)
    end

    context "presales" do
      before :each do
        @event.update_column(:state, "presales")
        visit page_event_path(@page.slug, @event.slug)
      end

      it "supports reservations" do
        button = find(:css, "div.event-summary-and-links-container a.bold_button")

        expect(button).to have_text("Reserve seats")

        button.click()

        expect(page).to have_current_path(new_page_event_order_path(@page.slug, @event.slug))
        expect(page).to have_text("Reserve seats")
      end
    end # 'context "presales" do'

    context "reserver payments" do
      before :each do
        @event.update_column(:state, "reserver_purchases")
        visit page_event_path(@page.slug, @event.slug)
      end

      it 'asks people to check their magic links' do
        button = find(:css, "div.event-summary-and-links-container a.bold_button")

        expect(button).to have_text("Pay for reservation")

        button.click()

        expect(page).to have_current_path(new_page_event_order_path(@page.slug, @event.slug))
        expect(page).to have_text("Pay for reservation")
      end
    end # 'context "reserver payments" do

    context "general sales" do
      before :each do
        @event.update_column(:state, "public_purchases")
        visit page_event_path(@page.slug, @event.slug)
      end

      it 'supports payments' do
        button = find(:css, "div.event-summary-and-links-container a.bold_button")

        expect(button).to have_text("Book seats")

        button.click()

        expect(page).to have_current_path(new_page_event_order_path(@page.slug, @event.slug))
        expect(page).to have_text("Book seats")
      end
    end # 'context "general sales" do'
  end # 'context "states" do'
end

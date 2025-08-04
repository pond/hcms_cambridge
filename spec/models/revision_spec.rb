require "spec_helper.rb"

RSpec.describe Revision, type: :model do
  context "scopes" do
    it "sorts by newest first by default" do
      page_1 = create(:page); page_1.revisions.first.update_column(:created_at, Time.now)
      page_2 = create(:page); page_2.revisions.first.update_column(:created_at, Time.now - 1.day)
      page_3 = create(:page); page_3.revisions.first.update_column(:created_at, Time.now + 1.day)

      expect(Revision.all.to_a).to eql([page_3, page_1, page_2].map(&:revisions).map(&:first))
    end

    it "::published" do
      page = create(:page)

      expect(Revision.count).to eql(1)
      expect(Revision.published).to be_empty

      published_revision = create(:revision, revisable: page, published: true)

      expect(Revision.count).to eql(2)
      expect(Revision.published).to match_array([published_revision])
    end

    it "::current" do
      page = create(:page)

      expect(Revision.count).to eql(1)
      expect(Revision.current).to match_array(page.revisions)

      Revision.update_all(current: false) # (don't assume only-one-current behaviour in this test)
      new_current_revision = create(:revision, revisable: page, current: true)

      expect(Revision.count).to eql(2)
      expect(Revision.current).to match_array([new_current_revision])
    end
  end

  context "exclusivity" do
    it "auto-sets 'current' on save" do
      page             = create(:page)
      initial_revision = page.revisions.first

      expect(page.revisions.count).to eql(1)
      expect(page.revisions.map(&:current)).to match_array([true])
      expect(initial_revision.current).to eql(true)

      new_revision = Revision.create!(
        revisable: page,
        title:     "Hello",
        body:      "World"
      )

      expect(page.reload.revisions.count).to eql(2)
      expect(new_revision.current).to eql(true)
      expect(initial_revision.reload.current).to eql(false)
    end

    it "only allows one 'current' per revisable scope" do
      page_1 = create(:page)
      page_2 = create(:page)

      expect(page_1.revisions.map(&:current)).to match_array([true])

      expect(Revision        .count).to eql(2)
      expect(Revision.current.count).to eql(2)
      expect(Revision.current      ).to match_array([page_1.revisions.first, page_2.revisions.first])

      new_current_revision = create(:revision, revisable: page_1) # (will auto-set 'current' on save)

      # Most recent addition should now be current
      #
      expect(page_1.reload.revisions.pluck(:id)).to eql([new_current_revision.id, page_1.revisions.last.id])
      expect(page_1.revisions.map(&:current)).to match_array([true, false])

      expect(Revision        .count).to eql(3)
      expect(Revision.current.count).to eql(2)
      expect(Revision.current      ).to match_array([page_1.revisions.first, page_2.revisions.first])
    end

    it "only allows one 'published' per revisable scope" do
      page_1 = create(:page); page_1.revisions.first.update_column(:published, true)
      page_2 = create(:page); page_2.revisions.first.update_column(:published, true)

      expect(page_1.revisions.map(&:published)).to match_array([true])

      expect(Revision          .count).to eql(2)
      expect(Revision.published.count).to eql(2)
      expect(Revision.published      ).to match_array([page_1.revisions.first, page_2.revisions.first])

      new_published_revision = create(:revision, revisable: page_1, published: true)

      # Most recent addition should now be published
      #
      expect(page_1.reload.revisions.pluck(:id)).to eql([new_published_revision.id, page_1.revisions.last.id])
      expect(page_1.revisions.map(&:published)).to match_array([true, false])

      expect(Revision          .count).to eql(3)
      expect(Revision.published.count).to eql(2)
      expect(Revision.published      ).to match_array([page_1.revisions.first, page_2.revisions.first])
    end
  end

  context "#current_draft?" do
    it "returns 'true' only if current and unpublished" do
      revision = Revision.new # Until saved, 'current' floats at default-false

      expect(revision.current_draft?).to eql(false)

      revision.current = true

      expect(revision.current_draft?).to eql(true)

      revision.published = true

      expect(revision.current_draft?).to eql(false)
    end
  end

  context "#display_name" do
    around :each do | example |
      travel_to(Time.now) do
        example.run # (avoid clock drift between consecutive lines of test code)
      end
    end

    it "'published' overrides 'current'" do
      revision = Revision.new(published: true, current: true, updated_at: Time.now - 1.day)

      expect(revision.display_name).to eql(I18n.t('models.revision.published'))
    end

    it "current draft if 'current' but not 'published'" do
      revision = Revision.new(published: false, current: true, updated_at: Time.now - 1.day)

      expect(revision.display_name).to eql(I18n.t('models.revision.current', time: revision.updated_at.to_fs(:short)))
    end

    it "unused if neither 'current' nor 'published'" do
      revision = Revision.new(published: false, current: false, updated_at: Time.now - 1.day)

      expect(revision.display_name).to eql(I18n.t('models.revision.unpublished', time: revision.updated_at.to_fs(:short)))
    end
  end
end

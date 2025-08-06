require "spec_helper.rb"

# Since this tests various features including persistence and scopes, tests use
# the Page model. That's why the first test makes sure Editable is involved,
# which isn't 100% concrete (Page could override anything) but it's a start.
#
# In-text comments explaining rationale are usually read first-test-to-last, as
# later tests which do the same things do not have copy-paste comments. When in
# doubt, scroll upwards to see if an earlier similar test has commentary.
#
RSpec.describe Editable, type: :model do
  it "is in use by the used-for-tests class" do
    expect(Page.ancestors).to include(Editable)
  end

  context "validations" do
    it "validates title and body presence" do
      editable = Page.new(revisions: [Revision.new(current: true)])
      editable.validate

      expect(editable.errors.of_kind?(:title, :blank)).to eql(true)
      expect(editable.errors.of_kind?(:body,  :blank)).to eql(true)

      editable = Page.new(revisions: [Revision.new(current: true, title: "Quick Brown Fox", body: "<p>Jumps</p>")])
      editable.validate

      expect(editable).to be_valid
    end

    it "generates a unique slug before validation, if none is given" do
      title = "Quick Brown Fox"
      body  = "<p>Jumps</p>"

      editable = Page.new(revisions: [Revision.new(current: true, title:, body:)])
      editable.validate

      expect(editable.slug).to eql("quick-brown-fox")

      editable.save! # (should succeed)

      2.upto(5) do |number|
        other_editable = Page.new(revisions: [Revision.new(current: true, title:, body:)])
        other_editable.validate

        expect(other_editable.slug).to eql("quick-brown-fox-#{number}")

        other_editable.save! # (should succeed)
      end
    end

    it "allows a specific slug to be specified" do
      editable = Page.new(slug: "hello-world", revisions: [Revision.new(current: true, title: "Quick Brown Fox")])
      editable.validate

      expect(editable.slug).to eql("hello-world")
    end

    it "validates slug uniqueness" do
      create(:page, slug: "hello-world")
      editable = Page.new(slug: "hello-world", revisions: [Revision.new(current: true, title: "Quick Brown Fox", body: "<p>Jumps</p>")])
      editable.validate

      expect(editable.errors.of_kind?(:slug, :taken)).to eql(true)
    end
  end # 'context "validations" do'

  context "delegation" do
    context "default" do
      context "reads" do
        it "take published over current" do
          editable = build(:page)
          title    = editable.revisions.first.title

          # Note that this is all just built in RAM without saving, avoiding
          # having to work around the Revision set-current-on-save behaviour.
          # Some amount of FactoryBot factory behaviour is assumed here.
          #
          editable.revisions << build(:revision, :for_page, published: true,  title: title + "-2")
          editable.revisions << build(:revision, :for_page, published: false, title: title + "-3")

          expect(editable.revisions.map(&:current  )).to eql([true,  false, false])
          expect(editable.revisions.map(&:published)).to eql([false, true,  false])
          expect(editable.revisions.map(&:title    )).to eql([title, title + "-2", title + "-3"])

          expect(editable.title).to eql(title + "-2") # Used the Published revision
        end

        it "fall back to current" do
          editable = build(:page)
          title    = editable.revisions.first.title

          editable.revisions << build(:revision, :for_page, published: false,  title: title + "-2")
          editable.revisions << build(:revision, :for_page, published: false, title: title + "-3")

          expect(editable.revisions.map(&:current  )).to eql([true,  false, false])
          expect(editable.revisions.map(&:published)).to eql([false, false, false])
          expect(editable.revisions.map(&:title    )).to eql([title, title + "-2", title + "-3"])

          expect(editable.title).to eql(title) # Used the original, still Current revision
        end

        it "break otherwise (bad data 'no current or published revision' unrecoverable case)" do
          editable           = build(:page)
          editable.revisions = build_list(:revision, 2, :for_page, current: false, published: false)

          expect { editable.title }.to raise_error(ActiveSupport::DelegationError)
        end
      end # 'context "reads" do'

      context "writes" do
        it "always fail" do
          editable = build(:page)
          editable.revisions << build(:revision, :for_page, published: true)

          expect(editable.revisions.map(&:current  )).to eql([true,  false])
          expect(editable.revisions.map(&:published)).to eql([false, true ])

          # Despite there being both a current and a published Revision...
          #
          expect { editable.title = "Written" }.to raise_error(ActiveSupport::DelegationError)
        end
      end # 'context "writes" do'
    end # 'context "default" do'

    context "#for_edit!" do
      context "reads" do
        it "take current over published" do
          editable = build(:page).for_edit!
          title    = editable.revisions.first.title

          editable.revisions << build(:revision, :for_page, published: true,  title: title + "-2")
          editable.revisions << build(:revision, :for_page, published: false, title: title + "-3")

          expect(editable.revisions.map(&:current  )).to eql([true,  false, false])
          expect(editable.revisions.map(&:published)).to eql([false, true,  false])
          expect(editable.revisions.map(&:title    )).to eql([title, title + "-2", title + "-3"])

          expect(editable.title).to eql(title) # Used the Current revision
        end

        it "fall back to published (bad data 'no current revision' self-healing case)" do
          editable = build(:page).for_edit!
          title    = editable.revisions.first.title

          editable.revisions << build(:revision, :for_page, published: true,  title: title + "-2")
          editable.revisions << build(:revision, :for_page, published: false, title: title + "-3")

          editable.revisions.each { |revision| revision.current = false }

          expect(editable.revisions.map(&:current  )).to eql([false, false, false])
          expect(editable.revisions.map(&:published)).to eql([false, true,  false])
          expect(editable.revisions.map(&:title    )).to eql([title, title + "-2", title + "-3"])

          expect(editable.title).to eql(title + "-2") # Used the Published revision
        end

        it "uses a blank draft otherwise (bad data 'no current or published revisions' self-healing case)" do
          editable = build(:page).for_edit!
          title    = editable.revisions.first.title

          editable.revisions << build(:revision, :for_page, published: false, title: title + "-2")
          editable.revisions << build(:revision, :for_page, published: false, title: title + "-3")
          editable.revisions.each { |revision| revision.current = false }

          expect(editable.title).to be_nil # Builds and reads from the blank draft

          # Note now that reading revision data yields *four* items, since a
          # blank draft got built when we used the attribute reader above. The
          # new revision is marked Current.
          #
          expect(editable.revisions.map(&:current  )).to eql([false, false, false, true ])
          expect(editable.revisions.map(&:published)).to eql([false, false, false, false])
          expect(editable.revisions.map(&:title    )).to eql([title, title + "-2", title + "-3", nil])
        end

        it "uses a blank draft otherwise ('brand new Editable' case)" do
          editable = Page.new.for_edit!

          expect(editable.title                    ).to be_nil # (rather than ActiveSupport::DelegationError)
          expect(editable.revisions.size           ).to eql(1)
          expect(editable.revisions.first.current  ).to eql(true)
          expect(editable.revisions.first.published).to eql(false)
        end
      end # 'context "reads" do'

      context "writes" do
        it "use current over published" do
          editable  = build(:page).for_edit!
          title     = editable.revisions.first.title
          new_title = SecureRandom.uuid

          editable.revisions << build(:revision, :for_page, published: true,  title: title + "-2")
          editable.revisions << build(:revision, :for_page, published: false, title: title + "-3")

          expect(editable.revisions.map(&:current  )).to eql([true, false, false])
          expect(editable.revisions.map(&:published)).to eql([false, true, false])
          expect(editable.revisions.map(&:title    )).to eql([title, title + "-2", title + "-3"])

          editable.assign_attributes(title: new_title, body: SecureRandom.uuid)

          expect(editable.revisions.map(&:title)).to eql([new_title, title + "-2", title + "-3"]) # Wrote to Current revision
        end

        it "uses a blank draft otherwise (bad data 'missing current unpublished revision' self-healing case)" do
          editable  = build(:page).for_edit!
          title     = editable.revisions.first.title
          new_title = SecureRandom.uuid

          # Even though there's a Published revision, we should never overwrite
          # that; should always be using the current unpublished, or new draft.
          #
          editable.revisions << build(:revision, :for_page, published: true,  title: title + "-2")
          editable.revisions << build(:revision, :for_page, published: false, title: title + "-3")
          editable.revisions.each { |revision| revision.current = false }

          editable.assign_attributes(title: new_title, body: SecureRandom.uuid)

          # The write accessor use above meant a new Current draft was added.
          #
          expect(editable.revisions.map(&:current  )).to eql([false, false, false, true ])
          expect(editable.revisions.map(&:published)).to eql([false, true,  false, false])
          expect(editable.revisions.map(&:title    )).to eql([title, title + "-2", title + "-3", new_title])
        end

        it "uses a blank draft otherwise ('brand new Editable' case)" do
          editable  = Page.new.for_edit!
          new_title = SecureRandom.uuid

          editable.assign_attributes(title: new_title, body: SecureRandom.uuid)

          expect(editable.title                    ).to eql(new_title)
          expect(editable.revisions.size           ).to eql(1)
          expect(editable.revisions.first.current  ).to eql(true)
          expect(editable.revisions.first.published).to eql(false)
          expect(editable.revisions.first.title    ).to eql(new_title)
        end
      end # 'context "writes" do'
    end # 'context "#for_edit!" do'

    context "#use_revision!" do
      context "reads" do
        it "use the specified revision" do
          editable = build(:page)
          title    = editable.revisions.first.title

          editable.revisions << build(:revision, :for_page, published: true,  title: title + "-2")
          editable.revisions << build(:revision, :for_page, published: false, title: title + "-3")

          expect(editable.revisions.map(&:current  )).to eql([true,  false, false])
          expect(editable.revisions.map(&:published)).to eql([false, true,  false])
          expect(editable.revisions.map(&:title    )).to eql([title, title + "-2", title + "-3"])

          editable.use_revision!(editable.revisions.last)

          expect(editable.title).to eql(title + "-3") # Used the last revision, ignoring current and published
        end
      end # 'context "reads" do'

      context "writes" do
        it "uses the current unpublished revision if that matches what was specified" do
          editable  = build(:page)
          title     = editable.revisions.first.title
          new_title = SecureRandom.uuid

          editable.revisions << build(:revision, :for_page, published: true,  title: title + "-2")
          editable.revisions << build(:revision, :for_page, published: false, title: title + "-3")

          editable.use_revision!(editable.revisions.first) # This is the current, unpublished record
          editable.assign_attributes(title: new_title, body: SecureRandom.uuid)

          expect(editable.revisions.map(&:current  )).to eql([true,  false, false])
          expect(editable.revisions.map(&:published)).to eql([false, true,  false])
          expect(editable.revisions.map(&:title    )).to eql([new_title, title + "-2", title + "-3"]) # Used the given revision
        end

        it "uses a copy of the specified revision if that revision is published" do
          editable  = build(:page)
          title     = editable.revisions.first.title
          new_title = SecureRandom.uuid

          editable.revisions << build(:revision, :for_page, published: true,  title: title + "-2")
          editable.revisions << build(:revision, :for_page, published: false, title: title + "-3")

          editable.use_revision!(editable.revisions.second) # This is the published record
          editable.assign_attributes(title: new_title, body: SecureRandom.uuid)

          # Expect to see a new current, unpublished draft. We haven't saved
          # anything yet so might expect the first revision to still be marked
          # as current too, but that's handled when the new draft is made.
          #
          expect(editable.revisions.map(&:current  )).to eql([false, false, false, true ])
          expect(editable.revisions.map(&:published)).to eql([false, true,  false, false])
          expect(editable.revisions.map(&:title    )).to eql([title, title + "-2", title + "-3", new_title])
        end

        it "uses a copy of the specified revision if that revision is neither published nor current" do
          editable  = build(:page)
          title     = editable.revisions.first.title
          new_title = SecureRandom.uuid

          editable.revisions << build(:revision, :for_page, published: true,  title: title + "-2")
          editable.revisions << build(:revision, :for_page, published: false, title: title + "-3")

          editable.use_revision!(editable.revisions.last) # This is neither published nor current
          editable.assign_attributes(title: new_title, body: SecureRandom.uuid)

          expect(editable.revisions.map(&:current  )).to eql([false, false, false, true ])
          expect(editable.revisions.map(&:published)).to eql([false, true,  false, false])
          expect(editable.revisions.map(&:title    )).to eql([title, title + "-2", title + "-3", new_title])
        end
      end # 'context "writes" do'
    end # 'context "#use_revision!" do'
  end # 'context "delegation" do'

  context "persistence" do
    context "#persist!" do
      it "saves and reports success" do
        page   = Page.new.for_edit!
        title  = "Quick Brown Fox"
        body   = "<p>Jumps</p>"
        result = page.persist!({title:, body:}, publish: false)

        expect(result.successful).to eql(true)
        expect(result.published ).to eql(false)

        page.reload

        expect(page.title                    ).to eql(title)
        expect(page.body                     ).to eql(body)
        expect(page.revisions.size           ).to eql(1)
        expect(page.revisions.first.current  ).to eql(true)
        expect(page.revisions.first.published).to eql(false)
      end

      it "tries to save but reports failure" do
        page   = Page.new.for_edit!
        result = page.persist!({title: nil, body: nil}, publish: false)

        expect(result.successful).to eql(false)
        expect(result.published ).to eql(false)
      end

      it "saves and publishes, reporting both" do
        page   = Page.new.for_edit!
        title  = "Quick Brown Fox"
        body   = "<p>Jumps</p>"
        result = page.persist!({title:, body:}, publish: true)

        expect(result.successful).to eql(true)
        expect(result.published ).to eql(true)

        page.reload

        expect(page.title                    ).to eql(title)
        expect(page.body                     ).to eql(body)
        expect(page.revisions.size           ).to eql(1)
        expect(page.revisions.first.current  ).to eql(true)
        expect(page.revisions.first.published).to eql(true)
      end

      it "does not report publishing of a failed save" do
        page   = Page.new.for_edit!
        result = page.persist!({title: nil, body: nil}, publish: true)

        expect(result.successful).to eql(false)
        expect(result.published ).to eql(false)
      end
    end # 'context "#persist!" do'
  end # 'context "persistence" do'

  context "utilities" do
    context "#published_revision" do
      it "returns the published revision if there is one" do
        editable = build(:page)
        editable.revisions.first.published = true

        expect(editable.published_revision).to eql(editable.revisions.first)
      end

      it "returns 'nil' if there is no published revision'" do
        editable = build(:page)
        editable.revisions.first.published = false

        expect(editable.published_revision).to be_nil
      end
    end # 'context "#published_revision" do'

    context "#current_revision" do
      it "returns the current revision if there is one" do
        editable = build(:page)
        editable.revisions.first.current = true

        expect(editable.current_revision).to eql(editable.revisions.first)
      end

      it "returns 'nil' if there is no current revision'" do
        editable = build(:page)
        editable.revisions.first.current = false

        expect(editable.current_revision).to be_nil
      end
    end # 'context "#current_revision" do'"

    context "#draft_revision" do
      it "returns the current revision if there is one and it is unpublished" do
        editable           = build(:page)
        revision           = editable.revisions.first
        revision.current   = true
        revision.published = false

        expect(editable.draft_revision).to eql(revision)
        expect(editable.revisions.size).to eql(1)
      end

      it "returns a blank draft current revision if there is a current revision but it is unpublished" do
        editable           = build(:page)
        revision           = editable.revisions.first
        revision.current   = true
        revision.published = true

        expect(editable.draft_revision        ).to_not eql(revision)
        expect(editable.draft_revision.title  ).to     be_nil
        expect(editable.draft_revision.current).to     eql(true)
        expect(editable.revisions.size        ).to     eql(2)
      end

      it "returns a blank draft current revision if there is no current revision (bad data self-healing case)" do
        editable           = build(:page)
        revision           = editable.revisions.first
        revision.current   = false
        revision.published = false

        expect(editable.draft_revision        ).to_not eql(revision)
        expect(editable.draft_revision.title  ).to     be_nil
        expect(editable.draft_revision.current).to     eql(true)
        expect(editable.revisions.size        ).to     eql(2)
      end
    end # 'context "#draft_revision" do'

    context "#displayed_revision" do
      it "routes through the 'current revision for reading' delegator" do # (delegation is already thoroughly tested; no need to repeat that!)
        editable = build(:page)

        expect(editable).to receive(:read_revision_for_delegation).once.and_return("Called")
        expect(editable.displayed_revision).to eql("Called")
      end
    end # 'context "#displayed_revision" do'

    context "::find_by_id_or_slug!" do
      it "finds when given a valid identifier" do
        editable = create(:page)

        expect(Page.find_by_id_or_slug!(editable.id     )).to eql(editable)
        expect(Page.find_by_id_or_slug!(editable.id.to_s)).to eql(editable)
        expect(Page.find_by_id_or_slug!(editable.slug   )).to eql(editable)
      end

      it "raises 'not found' when given an invalid identifier" do
        expect(Page.count).to be_zero # (self-check)

        expect{ Page.find_by_id_or_slug!(1)         }.to raise_error(ActiveRecord::RecordNotFound)
        expect{ Page.find_by_id_or_slug!("1")       }.to raise_error(ActiveRecord::RecordNotFound)
        expect{ Page.find_by_id_or_slug!("missing") }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end # 'context "::find_by_id_or_slug!" do'
  end # 'context "utilities" do'
end

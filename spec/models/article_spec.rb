require "spec_helper.rb"

RSpec.describe Article, type: :model do
  it "is an Editable" do # (because that's tested separately, so no need to duplicate tests here)
    expect(Article.ancestors).to include(Editable)
  end

  context "scopes and associations" do
    it "default scope orders newest-creation-time first" do
      page = create(:page, :blog)

      article_1 = create(:article, page: page, created_at: Time.now - 1.day)
      article_2 = create(:article, page: page, created_at: Time.now + 1.day)
      article_3 = create(:article, page: page, created_at: Time.now)

      expect(article_1.page).to eql(page) # (basic sanity check)
      expect(article_2.page).to eql(page)
      expect(article_3.page).to eql(page)

      expect(Article.all.to_a).to eql([article_2, article_3, article_1])
    end

    it "::for_navigation only includes published articles" do
      page = create(:page, :blog)

      article_1 = create(:article, page: page); article_1.revisions.update_all(published: false)
      article_2 = create(:article, page: page); article_2.revisions.update_all(published: true)
      article_3 = create(:article, page: page); article_3.revisions.update_all(published: true)

      expect(Article.for_navigation).to match_array([article_2, article_3])
    end
  end # 'context "scopes and associations" do'

  context "validations" do
    it "requires a title, summary, body and hero image" do
      article = build(:article)

      expect(article).to be_valid # (self-check)

      article.revisions.first.summary = nil

      expect(article).to_not be_valid
      expect(article.errors.of_kind?(:summary, :blank)).to eql(true)

      article.revisions.first.summary = "OK"

      expect(article).to be_valid

      article.revisions.first.body = nil

      expect(article).to_not be_valid
      expect(article.errors.of_kind?(:body, :blank)).to eql(true)

      article.revisions.first.body = "<p>OK</p>"

      expect(article).to be_valid

      article.article_hero_image = nil

      expect(article).to_not be_valid
      expect(article.errors.of_kind?(:article_hero_image, :blank)).to eql(true)
    end
  end # 'context "validations" do'

  it "responds correctly to trait enquiries" do
    article = build(:article)

    expect(article.is_normal_type?).to eql(false)
    expect(article.is_blog_type?  ).to eql(false)
    expect(article.is_form_type?  ).to eql(false)
    expect(article.is_events_type?).to eql(false)
    expect(article.is_article?    ).to eql(true)
    expect(article.is_event?      ).to eql(false)
  end

  context "base class overrides" do
    context "#for_navigation?" do
      it "returns 'true' for a not-hidden page with a published revision" do
        page = create(:page)

        article_1 = create(:article, page: page); article_1.revisions.update_all(published: false)
        article_2 = create(:article, page: page); article_2.revisions.update_all(published: true)
        article_3 = create(:article, page: page); article_3.revisions.update_all(published: true)

        expect(article_1.for_navigation?).to eql(false)
        expect(article_2.for_navigation?).to eql(true)
        expect(article_3.for_navigation?).to eql(true)
      end
    end # 'context "#for_navigation?" do'
  end # 'context "base class overrides" do'
end

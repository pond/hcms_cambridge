class BackfillRevisions < ActiveRecord::Migration[8.0]
  def up
    Page.find_each do | page |
      page.revisions.create(
        page.attributes
          .slice("created_at", "updated_at", *Revision::REVISABLE_ATTRIBUTES)
          .merge(published: true, current: true)
      )
    end

    Article.find_each do | article |
      article.revisions.create(
        article.attributes
          .slice("created_at", "updated_at", *Revision::REVISABLE_ATTRIBUTES)
          .merge(published: true, current: true)
      )
    end
  end

  def down
    Page.find_each do | page |
      page.revisions.find_by(created_at: page.created_at)&.destroy
    end

    Article.find_each do | article |
      article.revisions.find_by(created_at: article.created_at)&.destroy
    end
  end
end

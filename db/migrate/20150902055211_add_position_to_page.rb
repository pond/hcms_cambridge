class AddPositionToPage < ActiveRecord::Migration
  def change
    add_column :pages, :position, :integer

    # Before acts-as-list, pages had a default scope sorting by
    # creation date ascending. Migrate any existing pages to a
    # list by setting their positions explicitly using the same
    # ordering. Need to use 'reorder' as with the newer code, a
    # default scope ordering by position might otherwise take
    # precedence.

    position = 1

    Page.all.top_level.reorder( :created_at => :asc ).each do | page |
      page.position = position
      page.save!
      position += 1

      unless page.children.empty?
        sub_position = 1
        page.children.reorder( :created_at => :asc ).each do | sub_page |
          sub_page.position = sub_position
          sub_page.save!
          sub_position += 1
        end
      end
    end
  end
end

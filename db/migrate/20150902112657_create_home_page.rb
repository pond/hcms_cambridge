class CreateHomePage < ActiveRecord::Migration[4.2]
  def up
    Page.create :title => 'Home', :body => 'Welcome!' unless Page.count > 0
  end

  def down
  end
end

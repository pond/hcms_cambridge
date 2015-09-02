class CreateHomePage < ActiveRecord::Migration
  def up
    Page.create :title => 'Home', :body => 'Welcome!' unless Page.count > 0
  end

  def down
  end
end

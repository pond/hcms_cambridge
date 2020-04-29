class CreateHomePage < ActiveRecord::Migration[4.2]
  def up
    unless Page.count > 0
      page = Page.new :title => 'Home', :body => 'Welcome!'

      # Skip validation to avoid validations based on columns only added in
      # later migrations, from stopping this running now.
      #
      page.save(validate: false)
    end
  end

  def down
  end
end

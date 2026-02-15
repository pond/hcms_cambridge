namespace :setup do
  desc 'Create a starting-point Home page'
  task :home => :environment do | t, args |
    if Page.count > 0
      puts 'Doing nothing - at least one page is already present in the database'
    else
      puts 'Creating new Home page'

      page  = Page.new.for_edit!
      attrs = { title: 'Home', body: 'Welcome!' }

      page.persist!(attrs, publish: true)
    end
  end
end

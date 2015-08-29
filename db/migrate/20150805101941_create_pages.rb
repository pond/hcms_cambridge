class CreatePages < ActiveRecord::Migration
  def self.up
    create_table :pages do | t |

      # Initial bare minimum

      t.text :title, :null => false, :default => ''
      t.text :body,  :null => false, :default => ''

      t.belongs_to :page
      t.timestamps :null => false
    end

    Page.create :title => 'Home', :body => 'Welcome!'
  end

  def self.down
    drop_table :pages
  end
end

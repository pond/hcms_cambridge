# Remove not-null constraints from columns in tables represented by models that
# now delegate that information to a Revision.
#
class RemoveUnwantedNotNullConstraints < ActiveRecord::Migration[8.0]
  def change
    change_column_null :pages, :title, true
    change_column_null :pages, :body,  true

    change_column_null :articles, :title,   true
    change_column_null :articles, :body,    true
    change_column_null :articles, :summary, true
  end
end

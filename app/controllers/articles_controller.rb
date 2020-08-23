class ArticlesController < ApplicationController

  layout 'articles'

  def show
    @page    =    Page.find_by_id_or_slug!( params[ :page_id ] )
    @article = Article.find_by_id_or_slug!( params[ :id      ] )
  end
end

class ArticlesController < ApplicationController

  layout 'pages'

  IS_INTEGER = /\A\d+\z/

  def show
    if params[:id].nil?
      @page = Article.first # See default_scope in article.rb
    else
      @page = Article.find_by_id_or_slug!( params[ :id ] )
    end
  end
end

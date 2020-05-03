class ArticlesController < ApplicationController

  layout 'articles'

  IS_INTEGER = /\A\d+\z/

  def show
    if params[:id].nil?
      @article = Article.first # See default_scope in article.rb
    else
      @article = Article.find_by_id_or_slug!( params[ :id ] )
    end
  end
end

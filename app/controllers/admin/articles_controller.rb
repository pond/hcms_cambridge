class Admin::ArticlesController < ApplicationController

  layout :determine_layout

  # Via Devise
  before_action :authenticate_admin_user!
  before_action :set_page
  before_action :set_article, only: [ :show, :edit, :update, :destroy ]

  public

    # GET /admin/pages/<page_id>/articles
    def index
      @articles = Article.where(page_id: @page.id)
    end

    # GET /admin/pages/<page_id>/articles/<id>
    def show
    end

    # GET /admin/pages/<page_id>/articles/new
    def new
      @article = Article.new(page_id: @page.id)
    end

    # GET /admin/pages/<page_id>/articles/edit/<id>
    def edit
    end

    # POST /admin/pages/<page_id>/articles
    def create
      @article         = Article.new( article_params )
      @article.page_id = @page.id

      respond_to do | format |
        if @article.save
          format.html do
            redirect_to(
              admin_page_article_url( page_id: @page.id, id: @article.id ),
              notice: 'Article was successfully created.'
            )
          end
        else
          format.html { render :new }
        end
      end
    end

    # PATCH/PUT //admin/pages/<page_id>/articles/<id>
    def update
      respond_to do | format |
        if @article.update( article_params )
          if @article.previous_changes.has_key?( 'raw_editor' )
            format.html do
              redirect_to(
                edit_admin_page_article_url( page_id: @page.id, id: @article.id ),
                notice: 'Editing style changed.'
              )
            end
          else
            format.html do
              redirect_to(
                admin_page_article_url( page_id: @page.id, id: @article.id ),
                notice: 'Article was successfully updated.'
              )
            end
          end
        else
          format.html { render :edit }
        end
      end
    end

    # DELETE /admin/pages/<page_id>/articles/<id>
    def destroy
      @article.destroy

      respond_to do | format |
        format.html do
          redirect_to(
            admin_page_articles_url( page_id: @page.id ),
            notice: 'Article was successfully destroyed.'
          )
        end
      end
    end

  private

    def determine_layout
      case action_name
        when 'show'
          'articles'
        else
          'admin'
      end
    end

    def set_page
      @page = Page.find_by_id_or_slug!( params[ :page_id ] )
    end

    def set_article
      @article = Article.find_by_id_or_slug!( params[ :id ] )
    end

    def article_params
      params.require( :article ).permit( :title,
                                               :slug,
                                               :article_hero_image,
                                               :summary,
                                               :body,
                                               :raw_editor )
    end

end

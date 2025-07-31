class Admin::ArticlesController < ApplicationController

  layout :determine_layout

  # Via Devise
  before_action :authenticate_admin_user!
  before_action :get_page
  before_action :get_article,            only: [:show, :destroy]
  before_action :get_editable_article,   only: [:edit, :update]
  before_action :build_editable_article, only: [:new,  :create]

  public

    # GET /admin/pages/<page_id>/articles
    def index
      @articles = Article.where(page_id: @page.id)
    end

    # GET /admin/pages/<page_id>/articles/<id>
    def show
      if params.key?(:revision)
        @article.use_revision! @page.revisions.find(params[:revision])
      end
    end

    # GET /admin/pages/<page_id>/articles/new
    def new
    end

    # GET /admin/pages/<page_id>/articles/edit/<id>
    def edit
    end

    # POST /admin/pages/<page_id>/articles
    def create
      result = @article.persist!(self.article_params(), publish: params[:publish].present?)

      if result.successful
        if result.published
          redirect_to [:admin, @page, @article], notice: 'New article published.'
        else
          redirect_to [:admin, @page, @article, {revision: @article.current_draft_revision.id}], notice: 'New draft article created.'
        end
      else
        render :new
      end
    end

    # PATCH/PUT //admin/pages/<page_id>/articles/<id>
    def update
      result = @article.persist!(self.page_params(), publish: params[:publish].present?)

      if result.successful
        if @article.previous_changes.has_key?('raw_editor')
          if result.published
            redirect_to [:edit, :admin, @page, @article], notice: 'Editor selection altered and other changes, if any, published.'
          else
            redirect_to [:edit, :admin, @page, @article], notice: 'Editor selection altered.'
          end
        elsif result.published
          redirect_to [:admin, @page, @article], notice: 'Article changes published.'
        else
          redirect_to [:admin, @page, @article, {revision: @page.current_revision.id}], notice: 'Changes saved as draft.'
        end
      else
        render :edit
      end
    end

    # DELETE /admin/pages/<page_id>/articles/<id>
    def destroy
      @article.destroy

      respond_to do | format |
        format.html do
          redirect_to(
            admin_page_articles_url( page_id: @page.id ),
            notice: 'Article deleted.'
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

    def get_page
      @page = Page.find_by_id_or_slug!(params[:page_id])
    end

    def get_article
      @article = Article.find_by_id_or_slug!(params[:id])
    end

    def get_editable_article
      self.get_article.for_edit!
    end

    def build_editable_article
      @article = @page.articles.build.for_edit!
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

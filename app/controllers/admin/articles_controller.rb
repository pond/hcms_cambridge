class Admin::ArticlesController < ApplicationController

  layout :determine_layout

  # Via Devise
  before_action :authenticate_admin_user!
  before_action :get_page
  before_action :get_article,            only: [:show, :destroy]
  before_action :get_editable_article,   only: [:edit, :update]
  before_action :build_editable_article, only: [:new,  :create]
  before_action :check_for_revision,     only: [:show, :edit, :update]

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
    end

    # GET /admin/pages/<page_id>/articles/edit/<id>
    def edit
    end

    # POST /admin/pages/<page_id>/articles
    def create
      handle_form_submission(
        article:           @article,
        render_on_fail:    :new,
        draft_message:     'New draft article created.',
        published_message: 'New article published.'
      )
    end

    # PATCH/PUT //admin/pages/<page_id>/articles/<id>
    def update
      handle_form_submission(
        article:           @article,
        render_on_fail:    :edit,
        draft_message:     'Changes saved as draft.',
        published_message: 'Article changes published.'
      )
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

    def check_for_revision
      if params.key?(:revision)
        revision = @article.revisions.find(params[:revision])
        @article.use_revision!(revision)
      end
    end

    # Used by #create and #update; internal API, see callers for examples.
    #
    def handle_form_submission(
      article:,
      render_on_fail:,
      draft_message:,
      published_message:
    )
      result = article.persist!(self.article_params(), publish: params[:publish].present?)

      if result.successful
        if article.previous_changes.has_key?('raw_editor')
          if result.published
            redirect_to([:edit, :admin, article.page, article], notice: 'Editor selection altered and other changes, if any, published.')
          else
            redirect_to([:edit, :admin, article.page, article], notice: 'Editor selection altered.')
          end
        elsif result.published
          redirect_to(admin_page_article_path(article.page.slug, article.slug), notice: published_message)
        else
          redirect_to(admin_page_article_path(article.page.slug, article.slug, revision: article.current_revision.id), notice: draft_message)
        end
      else
        render(render_on_fail)
      end
    end

    def article_params
      params
        .require(:article)
        .permit(
          :title,
          :slug,
          :article_hero_image,
          :summary,
          :body,
          :raw_editor
        )
    end
end

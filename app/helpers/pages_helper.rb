module PagesHelper
  def form_page_selection_list( page )
    text  = page.form_selection_list_contents.strip
    items = text.split( "\n" )
    items.map! do | item |
      item.strip!
      OpenStruct.new( :form_value => item, :human_text => item )
    end

    collection_select( :selection, :selection, items, :form_value, :human_text )
  end
end

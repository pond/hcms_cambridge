require 'fileutils'
require 'open-uri'

# ...Where "leafname_base" is e.g. "this-slug-hero", resulting in something
# like "this-slug-hero.jpg" depending on "url"'s filename extension (which must
# be present).
#
def leafname_for(url, leafname_base)
  extname = File.extname(url)
  leafname_base + extname
end

def download(url, path, leafname)
  filename = File.join(path, leafname)

  unless File.exist?(filename)
    URI.open(url) do | image_object |
      File.open(filename, 'wb') do | file |
        file.write(image_object.read())
      end
    end
  end
end

namespace :migrate do
  desc 'Read dumped event pages from old website and build YAML data from it'
  task :parse => :environment do | t, args |
    output_yaml_path  = File.join(Rails.root, 'config', 'old_events.yml')
    output_image_path = File.join(Rails.root, 'config', 'old_event_images')
    dumped_event_root = '/Users/adh1003/Documents/Work/Wine Sentience/Archives - WACZ/data/www.winesentience.com/whats-on'
    yaml_data         = []

    FileUtils.mkdir_p(output_image_path)

    Dir.glob(File.join(dumped_event_root, '**/*')) do | path |
      next if File.directory?(path)

      puts '=' * 80
      puts path
      puts '-' * 80

      data = File.read(path)
      doc  = Nokogiri.parse(data)

      # Almost all information is easy to obtain in a JSON blob that always
      # appears as the first script payload in the HTML document.
      #
      event_meta           = JSON.parse(doc.css('script')[0].text)
      event_title          = event_meta['name']
      event_summary        = event_meta['description']
      event_hero_image_url = event_meta.dig('image', 0)
      event_date_time      = Time.parse(event_meta['doorTime'])
      event_place_name     = event_meta.dig('location', 'name')
      event_address        = event_meta.dig('location', 'address')

      if event_summary.blank?
        event_summary = event_title
      end

      if event_place_name.blank?
        event_place_name = 'Wine Sentience Hub'
        event_address    = 'Level 1, 104 Vivian Street, Wellington'
      end

      # The main description is sometimes included in a data attribute as well
      # as being part of the pre-rendered HTML page data. Otherwise, fall to
      # parsing nodes.
      #
      event_details_node = doc.css('article.eventitem div.eventitem-column-content div.product-block')
      event_details_json = event_details_node[0]['data-product'] if event_details_node.present?

      if event_details_json.present?
        event_details = JSON.parse(event_details_json)

        event_description    = event_details['description']
        event_body_image_url = event_details.dig('images', 0, 'assetUrl')
        event_price          = '$' + event_details.dig('price', 'value')
        event_slug           = event_details['urlSlug']
      else
        event_description    = event_summary # (but we might override this below)
        event_body_image_url = event_hero_image_url # (but we might override this below)
        event_price          = '' # Unknown
        event_slug           = File.basename(path)

        event_description_node = doc.css('article.eventitem div.eventitem-column-content div.sqs-html-content')

        if event_description_node.present?
          event_description     = doc.css('article.eventitem div.eventitem-column-content div.sqs-html-content')[0].inner_html.strip
          event_body_image_node = doc.css('article.eventitem div.eventitem-column-content div.image-block img')

          if event_body_image_node.present?
            event_body_image_url  = event_body_image_node[0]['src']
          end
        end
      end

      # Sanity check - bail out if we don't recognise anything
      #
      [
        event_title,
        event_hero_image_url,
        event_date_time,
        event_description,
        event_body_image_url,
        event_slug,
      ].each do | item |
        if item.blank?
          puts 'Event data missing'
          debugger
        end
      end

      has_body_image      = event_hero_image_url != event_body_image_url
      event_hero_leafname = leafname_for(event_hero_image_url, event_slug + '-hero')
      event_body_leafname = if has_body_image
        leafname_for(event_body_image_url, event_slug + '-body')
      else
        event_hero_leafname
      end

      # Special case work-around for weird 2K Adobe placeholder no-extension PNG
      #
      if event_hero_leafname == 'nouvelle-2019-wellington-on-a-plate-take-over-hero'
        event_hero_leafname << '.png'
        event_hero_image_url = event_body_image_url
      end

      event_title.gsub!('&amp;amp;', '&')
      event_summary.gsub!('&amp;amp;', '&')
      event_description.gsub!('&amp;amp;', '&amp;')

      yaml_data << {
        'slug'        => event_slug,
        'title'       => event_title,
        'summary'     => event_summary,
        'hero_image'  => event_hero_leafname,
        'date_time'   => event_date_time,
        'place_name'  => event_place_name,
        'address'     => event_address,
        'description' => event_description,
        'body_image'  => event_body_leafname,
        'price'       => event_price,
      }

      puts event_slug
      puts event_title
      puts event_summary
      puts event_hero_leafname
      puts event_place_name
      puts event_address
      puts '-' * 80
      puts event_description
      puts event_body_leafname
      puts event_price.inspect
      puts '=' * 80
      puts

      download(event_hero_image_url, output_image_path, event_hero_leafname)
      download(event_body_image_url, output_image_path, event_body_leafname) if has_body_image

    rescue => e
      puts "EXCEPTION: #{e.message}"
      puts e.backtrace[...6]
      puts '----'
      puts
      debugger
    end

    File.open(output_yaml_path, 'w') do | file |
      file.write(yaml_data.to_yaml)
    end

    puts "...Finished - #{yaml_data.size} events processed"
  end

  desc 'Read parsed YAML data and build database objects'
  task :create => :environment do | t, args |
    output_yaml_path  = File.join(Rails.root, 'config', 'old_events.yml')
    output_image_path = File.join(Rails.root, 'config', 'old_event_images')
    yaml_data         = YAML.load(File.read(output_yaml_path), permitted_classes: [Time])

    yaml_data.map!(&:with_indifferent_access)

    ActiveRecord::Base.transaction do
      blog_container   = Page.find_by_slug('previous-classes')
      blog_container ||= Page.new(
        hidden: true,
        raw_editor: false,
        page_type: Page::PAGE_TYPE_BLOG,
        slug: 'previous-classes',
        hide_date_and_time: false
      )

      if blog_container.revisions.empty?
        blog_container.revisions.build(
          title:            'Previous classes',
          navigation_title: 'Previous classes',
          published:        true,
          current:          true
        )

        blog_container.save!
      end

      yaml_data.each do |event|
        next if Article.find_by_slug(event[:slug])

        article = blog_container.articles.build(
          created_at:         event[:date_time],
          updated_at:         event[:date_time],
          slug:               event[:slug],
          article_hero_image: File.open(File.join(output_image_path, event[:hero_image])),
        )


        # STILL TO DO: Put main image at the top as if a Redactor upload
        # and add e.g. place & address somewhere


        article.revisions.build(
          created_at:       event[:date_time],
          updated_at:       event[:date_time],
          navigation_title: "Previous classes: #{event[:title]}",
          title:            event[:title],
          summary:          event[:summary],
          body:             event[:description],
          published:        true,
          current:          true
        )

        blog_container.save!
      end
    end

    # Rebuild the images download stuff if not already present
    # create-if-not-exists "Classes" blog container, not in main menu
    # else find it
    # iterate over YAML
    # create each article under that page
    # - hard part is the image*s*
  end
end

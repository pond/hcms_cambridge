require 'fileutils'
require 'open-uri'

def download(url, path, leafname)
  extname  = File.extname(url)
  filename = File.join(path, leafname + extname)

  unless File.exist?(filename)
    URI.open(url) do | image_object |
      File.open(filename, 'wb') do | file |
        file.write(image_object.read())
      end
    end
  end
end

namespace :migrate do
  desc "Read dumped event pages from old website and build YAML data from it"
  task :parse => :environment do | t, args |
    output_yaml_path  = File.join(Rails.root, 'config', 'old_events.yml')
    output_image_path = File.join(Rails.root, 'config', 'old_event_images')
    dumped_event_root = "/Users/adh1003/Documents/Work/Wine Sentience/Archives - WACZ/data/www.winesentience.com/whats-on"
    yaml_data         = []

    FileUtils.mkdir_p(output_image_path)

    Dir.glob(File.join(dumped_event_root, "**/*")) do | path |
      next if File.directory?(path)

      puts "=" * 80
      puts path
      puts "-" * 80

      data = File.read(path)
      doc  = Nokogiri.parse(data)

      # Almost all information is easy to obtain in a JSON blob that always
      # appears as the first script payload in the HTML document.
      #
      event_meta           = JSON.parse(doc.css("script")[0].text)
      event_title          = event_meta["name"]
      event_summary        = event_meta["description"]
      event_hero_image_url = event_meta.dig("image", 0)
      event_datetime       = Time.parse(event_meta["doorTime"])
      event_place_name     = event_meta.dig("location", "name")
      event_address        = event_meta.dig("location", "address")

      if event_summary.blank?
        event_summary = event_title
      end

      if event_place_name.blank?
        event_place_name = "Wine Sentience Hub"
        event_address    = "Level 1, 104 Vivian Street, Wellington"
      end

      # The main description is sometimes included in a data attribute as well
      # as being part of the pre-rendered HTML page data. Otherwise, fall to
      # parsing nodes.
      #
      event_details_node = doc.css("article.eventitem div.eventitem-column-content div.product-block")
      event_details_json = event_details_node[0]["data-product"] if event_details_node.present?

      if event_details_json.present?
        event_details = JSON.parse(event_details_json)

        event_description   = event_details["description"]
        event_alt_image_url = event_details.dig("images", 0, "assetUrl")
        event_price         = "$" + event_details.dig("price", "value")
        event_slug          = event_details["urlSlug"]
      else
        event_description   = event_summary # (but we might override this below)
        event_alt_image_url = event_hero_image_url # (but we might override this below)
        event_price         = "" # Unknown
        event_slug          = File.basename(path)

        event_description_node = doc.css("article.eventitem div.eventitem-column-content div.sqs-html-content")

        if event_description_node.present?
          event_description    = doc.css("article.eventitem div.eventitem-column-content div.sqs-html-content")[0].inner_html.strip
          event_alt_image_node = doc.css("article.eventitem div.eventitem-column-content div.image-block img")

          if event_alt_image_node.present?
            event_alt_image_url  = event_alt_image_node[0]["src"]
          end
        end
      end

      # Sanity check - bail out if we don't recognise anything
      #
      [
        event_title,
        event_hero_image_url,
        event_datetime,
        event_description,
        event_alt_image_url,
        event_slug,
      ].each do | item |
        if item.blank?
          puts "Event data missing"
          debugger
        end
      end

      yaml_data << {
        "event_slug"        => event_slug,
        "event_title"       => event_title,
        "event_summary"     => event_summary,
        "event_hero_image"  => event_slug + "-hero",
        "event_place_name"  => event_place_name,
        "event_address"     => event_address,
        "event_description" => event_description,
        "event_alt_image"   => event_slug + (event_hero_image_url != event_alt_image_url ? "-body" : "-hero"),
        "event_price"       => event_price,
      }

      puts event_slug
      puts event_title
      puts event_summary
      puts event_hero_image_url
      puts event_place_name
      puts event_address
      puts "-" * 80
      puts event_description
      puts event_alt_image_url
      puts event_price.inspect
      puts "=" * 80
      puts

      download(event_hero_image_url, output_image_path, event_slug + "-hero")

      if event_hero_image_url != event_alt_image_url
        download(event_alt_image_url, output_image_path, event_slug + "-body")
      end

    rescue => e
      puts "EXCEPTION: #{e.message}"
      puts e.backtrace[...6]
      puts "----"
      puts
      debugger
    end

    File.open(output_yaml_path, "w") do | file |
      file.write(yaml_data.to_yaml)
    end

    puts "...Finished - #{yaml_data.size} events processed"
  end

  desc "Read parsed YAML data and build database objects"
  task :create => :environment do | t, args |
    # create-if-not-exists "Classes" blog container, not in main menu
    # else find it
    # iterate over YAML
    # create each article under that page
    # - hard part is the image*s*
  end
end

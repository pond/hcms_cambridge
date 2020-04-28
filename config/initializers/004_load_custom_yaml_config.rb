Rails.application.config.uk_org_pond_hcms = OpenStruct.new( YAML.load_file( Rails.root.join( 'config' ).join( 'config.yml' ) ) )

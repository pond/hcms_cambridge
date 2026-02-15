# For a clean database, set up any values or other data not captured by
# "db/schema.rb".
#
if Page.count.zero?
  puts 'Creating new Home page'

  page  = Page.new.for_edit!
  attrs = { title: 'Home', body: 'Welcome!' }

  page.persist!(attrs, publish: true)
else
  puts 'Not creating new Home page - at least one Page already present'
end

if Order.count.zero?
  puts 'Setting psuedorandom initial invoice number'

  starting_invoice_number = rand(1001..1499)

  ActiveRecord::Base.connection.execute(
    <<~SQL
      ALTER SEQUENCE orders_invoice_number_seq RESTART WITH #{starting_invoice_number};
    SQL
  )
else
  puts 'Not resetting invoice numbers - at least one Order already present'
end

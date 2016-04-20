class ContactMailer < ApplicationMailer
  def contact_email( params )
    @name    = params[ 'name'    ]
    @email   = params[ 'email'   ]
    @phone   = params[ 'phone'   ]
    @message = params[ 'message' ]

    mail( :from => @email, :subject => 'Web site contact request' )
  end
end

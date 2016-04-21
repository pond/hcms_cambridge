class BookingMailer < ApplicationMailer
  def booking_email( params )
    @name    = params[ 'name'      ]
    @email   = params[ 'email'     ]
    @phone   = params[ 'phone'     ]
    @time    = params[ 'time'      ]
    @date    = params[ 'date'      ]
    @menu    = params[ 'selection' ].try( :[], 'selection' )
    @notes   = params[ 'notes'     ]

    mail( :from => @email, :subject => 'Web site booking request' )
  end
end

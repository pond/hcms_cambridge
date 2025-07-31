class User < ApplicationRecord

  # Include default devise modules. Others available at the time of generation:
  # :confirmable, :lockable, :timeoutable and :omniauthable.
  #
  devise(
    :database_authenticatable,
    :registerable,
    :recoverable,
    :rememberable,
    :trackable,
    :validatable
  )

end

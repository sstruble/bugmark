require 'ext/hash'

class Event::EscrowCaptured < Event

  jsonb_fields_for :payload, Escrow

  validates :uuid , presence: true

  def cast_object
    escrow
  end

  def escrow
    @esc ||= Escrow.new(payload.without_blanks)
  end

end

# == Schema Information
#
# Table name: events
#
#  id           :integer          not null, primary key
#  event_type   :string
#  event_uuid   :string
#  cmd_type     :string
#  cmd_uuid     :string
#  local_hash   :string
#  chain_hash   :string
#  payload      :jsonb            not null
#  jfields      :jsonb            not null
#  user_uuids   :string           default([]), is an Array
#  projected_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

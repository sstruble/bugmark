# integration_test: commands/contract_cmd/cross/reduce

require_relative '../commit'

class Commit::Reduce < Commit

  def generate
    ctx = base_context

    # look up contract
    ctx.c_contract = bundle.offer.obj.salable_position.contract
    ctx.c_uuid     = ctx.c_contract.uuid

    # generate amendment, escrow, price
    ctx.e_type = "Escrow::Reduce"
    ctx.a_type = "Amendment::Reduce"
    gen_escrow_and_amendment(ctx)

    # calculate price for offer and counter
    ctx.counter_price = bundle.counters.map {|el| el.obj.price}.min
    ctx.offer_price   = 1.0 - ctx.counter_price

    # generate artifacts
    expand_position(bundle.offer, ctx, ctx.offer_price)  # BUG HERE - NEED TO PAYOUT ...
    bundle.counters.each {|offer| expand_position(offer, ctx, ctx.counter_price)}

    # update escrow value
    ctx = update_escrow_value(ctx)

    self
  end

end
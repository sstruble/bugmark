require 'rails_helper'

RSpec.describe 'OfferBF Factory', USE_VCR do
  it "runs without params" do
    expect(Offer.count).to eq(0)
    FB.create(:offer_bf)
    expect(Offer.count).to eq(1)
  end

  it "has a default price and value" do
    result = FB.create(:offer_bf).offer
    expect(result.price).to_not be_nil
    expect(result.volume).to_not be_nil
  end

  it "generates a valid user" do
    offer = FB.create(:offer_bf).offer
    expect(User.count).to eq(1)
    expect(offer.user).to_not be_nil
  end

  it "accepts a user attribute" do
    usr   = FB.create(:user).user
    offer = FB.create(:offer_bf, user_uuid: usr.uuid).offer
    expect(offer.user).to eq(usr)
  end
end

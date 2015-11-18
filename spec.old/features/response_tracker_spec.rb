require 'spec_helper'

describe "Response tracker" do
  before :each do
    @pcmo = create :pcmo
    login @pcmo

    @new, @flagged, @old = [{created_at: 11.months.ago}, {flagged: true}, {received_at: 1.week.ago}].map do |attrs|
      pcv  = create :pcv, country: @pcmo.country
      resp = create :response, attrs.merge(user: pcv)
      resp.orders << create(:order, user: pcv)
      resp
    end

    visit responses_path
  end

  def row_for response
    find("tr", text: response.user.last_name)
  end

  it "shows past responses" do
    expect( page ).to have_content @new.user.last_name
    expect( page ).to have_content @flagged.user.last_name
  end

  it "shows which responses have been flagged" do
    expect( all("i.glyphicon-flag").count ).to eq 1

    flag = row_for(@flagged).find("i.glyphicon-flag")
    expect( flag[:class] ).to include "danger"
  end

  it "can show received responses" do
    expect( page ).not_to have_content @old.user.last_name

    click_on "Archived"
    expect( page ).to have_content @old.user.last_name
    expect( page ).not_to have_content @new.user.last_name

    click_on "All"
    expect( page ).to have_content @old.user.last_name
    expect( page ).to have_content @new.user.last_name
  end

  it "can view response detail" do
    duplicate = create(:order, duplicated_at: 2.weeks.ago)
    pickup    = create(:order, delivery_method: DeliveryMethod::Pickup)
    @old.orders << duplicate
    @old.orders << pickup

    click_on "Archived"
    row_for(@old).find("a", text: "Received").click
    expect( page ).to have_content @old.extra_text
    expect( find("tr", text: duplicate.supply.name) ).to have_content "Updated on"
    expect( find("tr", text: pickup.supply.name) ).to have_css ".glyphicon-ok"
  end

  it "allows PCMOs to see a volunteer's timeline" do
    send_text @new.user, "how do?"
    visit responses_path

    row_for(@new).find("a", text: "History").click
    expect( page ).to have_content "how do?"
    expect( page ).to have_content @new.extra_text
    expect( page ).to have_content @new.orders.first.request.text
  end

  it "allows PCMOs to mark responses as received" do
    row_for(@new).find("a", text: "Received").click

    expect( page ).not_to have_content @new.user.last_name
    expect( page.find ".flash" ).to have_content "archived"
    expect( @new.reload ).to be_received

    click_on "Archived"
    expect( row_for @new ).to have_content "Received on"
  end

  it "allows PCMOs to cancel responses outright" do
    row_for(@new).find("a", text: "Cancel").click

    expect( page ).not_to have_content @new.user.last_name
    expect( page.find ".flash" ).to have_content "cancelled"
    expect( @new.reload ).not_to be_received
    expect( @new ).to be_cancelled

    click_on "Archived"
    expect( row_for @new ).to have_content "Cancelled on"
  end

  it "allows PCMOs to cancel and re-request responses" do
    row_for(@new).find("a", text: "Reorder").click

    expect( page ).not_to have_content @new.user.last_name
    expect( page.find ".flash" ).to have_content "cancelled"
    expect( @new.reload ).not_to be_received
    expect( @new ).to be_cancelled

    click_on "Archived"
    expect( row_for @new ).to have_content "Reordered on"

    visit manage_orders_path
    expect( row_for @new ).to have_content @new.supplies.first.name

    req = Request.where(reorder_of: @new).first
    expect( req.supplies.to_a ).to eq @new.supplies.to_a
  end
end

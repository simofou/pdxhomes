# Use the Portland Maps API to grab data for an address
module PortlandMapsApi
  # require 'active_record'
  require 'faraday'
  require 'pry'
  require 'json'
  require 'active_support'
  require 'active_support/core_ext/numeric/conversions'
  require 'dotenv/load'

  API_KEY = ENV['PDX_MAPS_API_KEY']

  # Helper methods
  def owner_is_human?(owner)
    owner.include? ','
  end

  def owner_is_single_human?(owner)
    owner_is_human?(owner) && (!owner.include? '&')
  end

  def owner_is_multiple_humans?(owner)
    owner_is_human?(owner) && (owner.include? '&')
  end

  def format_single_owner(owner)
    owner = owner.strip.split(',')
    owner = owner.insert(0, owner.delete_at(1))
    owner = "#{owner[0].capitalize} #{owner[1].capitalize}"
  end

  def format_multiple_owners(owner)
    owner = owner.split('&')
    complete_owner = ""

    owner.each_with_index do |owner, i|
      if owner_is_human?(owner)  
        owner = format_single_owner(owner)
      end

      if i == 0
        complete_owner += owner
      else
        complete_owner += ' & ' + owner
      end
    end
    complete_owner
  end

  def format_owner(owner)
    if owner_is_single_human?(owner)
      format_single_owner(owner)  
    elsif owner_is_multiple_humans?(owner)
      format_multiple_owners(owner)
    else
      owner # owner is probably a business so who cares about formatting
    end
  end

  # Portland Maps methods
  def get_homeowner(address)
    # api call to portland maps to get owner name
    # ex httpie call:
    # http https://www.portlandmaps.com/api/assessor/ 
    # api_key=="api_key_goes_here" address=="4445 ne wygant"
    response_body = api_response_from(address)

    if response_body != nil
      owner = response_body["owner"]
      format_owner(owner)
    else
      puts "invalid address. please enter a valid addy foo"
      puts "try again foo"
      response_body # nil (stop calling stuff)
    end
  end

  def get_full_address(address)
    owner = get_homeowner(address)
    response_body = api_response_from(address)

    address_street = response_body["address"]
    address_city = response_body["city"]
    address_state = response_body["state"]
    address_zip_code = response_body["zip_code_string"]


    "#{address_street} #{address_city} #{address_state} #{address_zip_code}"
  end

  def get_lot_size(address)
    response_body = api_response_from(address)
    detail_id = response_body["property_id"]

    response = api_response_assessor(detail_id)

    body = JSON.parse(response.body)["general"]
    
    body["total_land_area"]
  end

  def get_lot_zoning(address)
    response_body = api_response_from(address)
    detail_id = response_body["property_id"]

    response = api_response_zoning(detail_id)

    body = JSON.parse(response.body)["zoning"]
    
    body["base_overlay_combination"][0]["code"]
  end

  def get_market_value(address)
    response_body = api_response_from(address)
    market_value = response_body["market_value"]
    
    market_value = market_value&.to_fs(:delimited)
  end

  def get_real_market_value(address)
    response_body = api_response_from(address)
    detail_id = response_body["property_id"]

    response = api_response_assessor(detail_id)

    body = JSON.parse(response.body)["assessment history"].first
    assesement_year = body["year"]
    real_market_value = body["real_market"]

    "#{real_market_value} (#{assesement_year})"
  end

  def get_property_taxes(address)
    response_body = api_response_from(address)
    detail_id = response_body["property_id"]

    response = api_response_assessor(detail_id)

    body = JSON.parse(response.body)["tax history"].first
    tax_year = body["year"]
    property_tax = body["property_tax"]

    "#{property_tax} (#{tax_year})"
  end

  def get_home_size(address)
    response_body = api_response_from(address)
    home_size_sqft = response_body["square_feet"]
    
    home_size_sqft&.to_fs(:delimited)
  end

  def get_foundation_type(address)
    response_body = api_response_from(address)
    detail_id = response_body["property_id"]

    response = api_response_assessor(detail_id)

    body = JSON.parse(response.body)
    segments = body["improvements"]["details"].map{|seg| seg["segment_type"]}
    foundation_type = body["improvements"]["foundation_type"]&.downcase

    if foundation_type == "concrete"
      if segments.to_s.include? "BSMT"
        foundation_type += " (basement)"
      else
        foundation_type += " (other)"
      end
    end

    foundation_type
  end

  def get_year_built(address)
    response_body = api_response_from(address)
    
    response_body["year_built"]
  end

  def get_location_coordinates(address)
    response_body = api_response_from(address)
    longitude = response_body["longitude"]
    latitude = response_body["latitude"]
    
    "#{longitude},#{latitude}"
  end

  def get_neighborhood(address)
    response_body = api_response_from(address)
    neighborhood = response_body["neighborhood"]

    if neighborhood == "CULLY ASSOCIATION OF NEIGHBORS"
      neighborhood = "Cully"
    end

    neighborhood.capitalize
  end

  private
  # Portland Maps API focused methods
  # the idea is to keep API calls to a minimum
  def connection
    url = "https://www.portlandmaps.com/api/"

    connection ||= Faraday.new(
      url: "#{url}",
      params: {api_key: "#{API_KEY}"},
      headers: {"Content-Type" => "application/json"}
    )
  end

  def api_response_from(address) 
    endpoint = "assessor/"
    address = address.to_s.downcase
    # notice the conditional assignment / instance variable:
    # only make the API call if it hasn't already been made in this session.
    @response_from_address ||= connection.get("#{endpoint}") do |request|
      request.params["address"] = "#{address}"
    end

    response_body = JSON.parse(@response_from_address.body)

    if response_body["status"] != "error"
      response_body["results"][0]
    else
      raise "status #{@response_from_address.status}: no response body, must be a bad request. check your .env, api key, and params foo"
    end
  end

  def api_response_detail(detail_id, detail_type)
    endpoint = "detail/"

    connection.get("#{endpoint}") do |request|
      request.params["detail_type"] = "#{detail_type}"
      request.params["detail_id"] = "#{detail_id}"
      request.params["sections"] = "*"
    end
  end

  def api_response_zoning(detail_id)
    # notice the conditional assignment / instance variable:
    # only make the API call if it hasn't already been made in this session.
    @response_zoning ||= api_response_detail(detail_id, "zoning")
  end

  def api_response_assessor(detail_id)
    @response_assessor ||= api_response_detail(detail_id, "assessor")
  end
end

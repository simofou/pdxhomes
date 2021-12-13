# So here we want to grab the zestimate for an address.
# BUT you can't pass an address as a param for the zestimate API... (dafuk?)
# SO closest thing is pass address AND location coordinates (from PDX MAPS)
# Then we use zillow API to return 100 addresses closest to those
# coordinates (within 0.1 miles) and store them, then search that array for our address...
module ZillowApi
  # require 'active_record'
  require 'faraday'
  require 'pry'
  require 'json'
  require 'active_support'
  require 'active_support/core_ext/numeric/conversions'
  require 'dotenv/load'

  API_KEY = ENV['ZILLOW_API_KEY']

  def get_zestimate(location_coordinates, address)
    address = address.upcase
    url = "https://api.bridgedataoutput.com/api/v2/zestimates"
  
    response ||= Faraday.get(url) do |req|
      req.params['access_token'] = API_KEY 
      req.params['limit'] = 100
      req.params['fields'] = 'zestimate,address'
      req.params['near'] = location_coordinates
      req.params['radius'] = 0.1
    end

    response_body = JSON.parse(response.body)
    zillow_home_data = response_body["bundle"] 
    # array of hashes - each hash is a home that matches our query and contains :address, :zestimate...
    zestimate = nil

    zillow_home_data.each do |home_data|
      next unless home_data["address"].upcase.include? "#{address}"
      if home_data["zestimate"] != nil
        zestimate = "#{home_data["zestimate"].to_s(:delimited)}"
      end
      break
    end

    zestimate
  end
end

module WalkScoreApi
  require 'faraday'
  require 'pry'
  require 'json'
  require 'dotenv/load'
  require 'active_support/core_ext/hash'

  API_KEY = ENV['WALK_SCORE_API_KEY']

  def get_response(location_coordinates, full_address)
    url =  "https://api.walkscore.com/score"
    lon = location_coordinates.split(',')[0]
    lat = location_coordinates.split(',')[1]
    url_address = CGI.escape full_address

    @response ||= Faraday.get(url) do |req|
      req.params['wsapikey'] = API_KEY 
      req.params['lat'] = lat
      req.params['lon'] = lon
      req.params['address'] = url_address 
      req.params['transit'] = 1
      req.params['bike'] = 1
    end

    Hash.from_xml(@response.body)
  end

  def get_walk_score(location_coordinates, full_address)
    response_body = get_response(location_coordinates, full_address)
    response_body["result"]["walkscore"]
  end

  def get_walk_score_help_link(location_coordinates, full_address)
    response_body = get_response(location_coordinates, full_address)
    response_body["result"]["help_link"]
  end
end

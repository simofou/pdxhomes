require 'rubygems'
require 'sinatra/base'
require 'sinatra'
require 'pry'
require_relative 'models/home.rb'


  get '/' do
    erb :index
  end

  post '/create' do
    address = params['address']
    @home = Home.new(address)

    if !@home.valid?
      erb :error
    elsif @home.valid? && @home.owner.nil?
      @home.errors.add :base, "address not in pdx database"
      erb :error
    else
      erb :create
    end
  end

#!/usr/bin/ruby
require 'rubygems'
require 'rexml/document'
require 'trollop'
require 'fileutils'
require 'cgi'
require 'net/http'

@DATA_URL = "http://apple.accuweather.com/adcbin/apple/Apple_Weather_Data.asp?zipcode"
@LOOKUP_URL = "http://apple.accuweather.com/adcbin/apple/Apple_find_city.asp?location"
@TEMP_FILE_DIR = "/Users/sandesh"
@TEMP_FILE_PREFIX = "acweather"
@TEMP_FILE_SUFFIX = "tmp"
@LOCK_FILE_SUFFIX = "lck"
@ICON_FILE_SUFFIX = "png"
@SHARED_ICON = "#{@TEMP_FILE_DIR}/acweather-icon.#{@ICON_FILE_SUFFIX}"
@ICON_LOCATION = "."

def temp_file_name(location)
  "#{@TEMP_FILE_DIR}/#{@TEMP_FILE_PREFIX}-#{CGI.escape(location)}.#{@TEMP_FILE_SUFFIX}"
end

def lock_file_name(location)
  "#{@TEMP_FILE_DIR}/#{@TEMP_FILE_PREFIX}-#{CGI.escape(location)}.#{@LOCK_FILE_SUFFIX}"
end

def temp_icon_name(location)
  "#{@TEMP_FILE_DIR}/acweather-icon-#{CGI.escape(opts[:zipcode])}.#{@ICON_FILE_SUFFIX}"
end

def titleize(text)
  small_words = %w(a an and as at but by en for if in of on or the to via vs. vs v v.)
  special_characters = %w(-^)

  string = text.split
  string.map! do |word|
    word.strip!

    if [string.first, string.last].include?(word) then word.capitalize! end

    next(word) if small_words.include?(word)
    next(word) if special_characters.include?(word)
    next(word) if word =~ /[A-Z]/

    word = begin
      unless (match = word.match(/[#{special_characters.to_s}]/))
        word.sub(/\w/) { |letter| letter.upcase }
      else
        word.split(match.to_s).map! {|word| word.capitalize }.join(match.to_s)
      end
    end
  end

  string.join(' ')
end

def pull_weather(location, max_age)
  # Check if another process is downloading the weather and block until it's done
  while File.file?(lock_file_name(location))
    sleep(0.1)
  end

  # Download the weather if it's out of date
  if !File.file?(temp_file_name(location)) || ((Time.now - File.mtime(temp_file_name(location))) > max_age)
    # Create the lock file
    FileUtils.touch(lock_file_name(location))
    
    `curl --silent -m 30 "#{@DATA_URL}=#{CGI.escape(location)}" > #{temp_file_name(location)}`
    if File.size(temp_file_name(location)) == 0
      FileUtils.rm(temp_file_name(location))
    end
    
    # Remove the lock file
    FileUtils.rm(lock_file_name(location))
  end
end

def lookup_postal(name)
  puts "Location = Postal code/Zipcode"
  xml_data = Net::HTTP.get_response(URI.parse("#{@LOOKUP_URL}=#{CGI.escape(name)}")).body
  
  # extract event information
  doc = REXML::Document.new(xml_data)
  
  doc.elements.each('adc_Database/CityList/location') do |ele|
    puts "#{ele.attributes['city']}, #{ele.attributes['state']} = #{ele.attributes['postal']}"
  end
end
  

def parse_weather(location)
  weather = {}
  
  doc = REXML::Document.new File.new(temp_file_name(location))
  
  time = (doc.elements.collect('adc_Database/CurrentConditions/Time') { |el| el.text.strip })[0]
  hour = time[0...2].to_i
  min = time[3..5]
  if hour < 12
    ampm = "AM"
  else
    ampm = "PM"
  end
  if hour == 0
    hour = 12
  end
  if hour > 12
    hour = hour - 12
  end
  weather["time"] = "#{hour}:#{min} #{ampm}"
  weather["temperature"] = (doc.elements.collect('adc_Database/CurrentConditions/Temperature') { |el| el.text.strip })[0]
  weather["realfeel"] = (doc.elements.collect('adc_Database/CurrentConditions/RealFeel') { |el| el.text.strip })[0]
  weather["pressure"] = (doc.elements.collect('adc_Database/CurrentConditions/Pressure') { |el| el.text.strip })[0]
  weather["humidity"] = ((doc.elements.collect('adc_Database/CurrentConditions/Humidity') { |el| el.text.strip })[0])[0...-1].to_i
  icon = (doc.elements.collect('adc_Database/CurrentConditions/WeatherIcon') { |el| el.text.strip })[0]
  weather["current_state"] = titleize((doc.elements.collect('adc_Database/CurrentConditions/WeatherText') { |el| el.text.strip })[0])
  weather["wind_speed"] = (doc.elements.collect('adc_Database/CurrentConditions/WindSpeed') { |el| el.text.strip })[0]
  weather["wind_direction"] = (doc.elements.collect('adc_Database/CurrentConditions/WindDirection') { |el| el.text.strip })[0]
  weather["forecast"] = (doc.elements.collect('adc_Database/Forecast/day/TXT_Long') { |el| el.text.strip })[0]
  weather["high_temperature"] = (doc.elements.collect('adc_Database/Forecast/day/High_Temperature') { |el| el.text.strip })[0]
  weather["low_temperature"] = (doc.elements.collect('adc_Database/Forecast/day/Low_Temperature') { |el| el.text.strip })[0]
  weather["icon"] = icon
  if icon.size != 0
    weather["icon_file"] = "#{@ICON_LOCATION}/#{icon}.png"
  end
  
  weather
end


opts = Trollop::options do
  opt :zipcode, "Zipcode to retrieve weather for", :type => String
  opt :summary, "Short summary of current conditions"
  opt :forecast, "Long-term weather forecast"
  opt :humidity, "Current humidity"
  opt :longtemperature, "Current temperature in long form"
  opt :temperature, "Current temperature"
  opt :realfeel, "Current RealFeel temperature"
  opt :current, "Current conditions"
  opt :icon, "Weather icon"
  opt :iconlocation, "Directory containing weather icons", :type => String
  opt :date, "Date the weather was created"
  opt :lookup, "Lookup a city postal code", :type => String
end

Trollop::die :zipcode, "must have a value" if opts[:zipcode] && opts[:zipcode].length == 0 
Trollop::die :lookup, "must have a value" if opts[:lookup] && opts[:lookup].length == 0 

if opts[:zipcode] && opts[:lookup] 
  puts "You must choose either --zipcode or --lookup, not both"
  exit
end

if opts[:lookup]
  lookup_postal(opts[:lookup])
  exit
end

if opts[:iconlocation]
  @ICON_LOCATION = opts[:iconlocation]
end  

pull_weather(opts[:zipcode], 1800)
weather = parse_weather(opts[:zipcode])

if weather['icon_file'].nil?
  FileUtils.rm(@SHARED_ICON) if File.file?(@SHARED_ICON)
else
  begin
    FileUtils.cp(weather['icon_file'], @SHARED_ICON)
    FileUtils.cp(weather['icon_file'], "/Users/sandesh/acweather-icon-#{CGI.escape(opts[:zipcode])}.png")
  rescue
    warn "Unable to read from icon file '#{weather['icon_file']}' in directory '#{@ICON_LOCATION}'.  Use the --iconlocation argument to provide the appropriate directory."
  end  
end

if opts[:summary]
  puts "#{weather['temperature']}F, #{weather['current_state']}"
end
if opts[:current]
  puts "#{weather['current_state']} #{weather['high_temperature']}/#{weather['low_temperature']} - #{weather['forecast']}"
end
if opts[:longtemperature]
  puts "#{weather['temperature']}F (#{weather['realfeel']}F)"
end
if opts[:temperature]
  puts "#{weather['temperature']}"
end
if opts[:realfeel]
  puts "#{weather['realfeel']}"
end
if opts[:humidity]
  puts weather['humidity']
end
if opts[:date]
  puts weather['time']
end
if opts[:icon]
  puts weather['icon_file']
end
if opts[:forecast]
  puts weather['forecast']
end

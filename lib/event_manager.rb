# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def week_day(day)
  days = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
  days[day % 7]
end

def get_day(reg_date)
  reg_date = reg_date.split(' ')
  temp_date = "20#{reg_date[0]}"
  date = Date.strptime(temp_date, '%Y/%d/%m').to_s
  time = reg_date[1].to_s
  temp_time = date.concat(32, time)
  week_day(Time.parse(temp_time).wday)
end

def peak_wday(days)
  results = days.reduce(Hash.new(0)) do |result, day| # rubocop:disable Style/EachWithObject
    result[day] += 1
    result
  end
  results.each_pair do |key, value|
    puts "Day of the week #{key}: amount registrations #{value}"
  end
end

def get_hour(reg_date)
  reg_date = reg_date.split(' ')
  temp_date = "20#{reg_date[0]}"
  date = Date.strptime(temp_date, '%Y/%d/%m').to_s
  time = reg_date[1].to_s
  temp_time = date.concat(32, time)
  Time.parse(temp_time).hour
end

def peak_hour(hours)
  results = hours.reduce(Hash.new(0)) do |result, hour| # rubocop:disable Style/EachWithObject
    result[hour] += 1
    result
  end
  results.each_pair do |key, value|
    puts "Hour #{key}: amount registrations #{value}"
  end
end

def clean_phone(phone_number)
  digits = '1234567890'.split('')
  filtered_phone_number = phone_number.split('').filter do |num|
    digits.include?(num)
  end
  return filtered_phone_number.join('') if filtered_phone_number.size == 10

  if filtered_phone_number.size == 11 && filtered_phone_number[0] == '1'
    filtered_phone_number.shift
    return filtered_phone_number.join('')
  end
  'A bad phone number!'
end

def legislators_by_zipcode(zip) # rubocop:disable Metrics/MethodLength
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read '../secret.key'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  '../event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('../form_letter.erb')
erb_template = ERB.new template_letter
hours = []
days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone = clean_phone(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  hour = get_hour(row[:regdate])
  hours.push(hour)
  day = get_day(row[:regdate])
  days.push(day)

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  puts "#{id} #{name} #{zipcode} #{phone}"
end
puts
peak_hour(hours)
puts
peak_wday(days)

require 'dotenv/load'
require 'open-uri'
require 'nokogiri'
require 'chunky_png'
require 'twitter'

def unique_and_sort(colors)
  colors.uniq { |c| c['kanji'] }.shuffle!(random: Random.new(Time.now.to_i))
end

def generate_colors
  if File.exist?('colors.json')
    return unique_and_sort(JSON.parse(File.read('colors.json')))
  end

  colors = []

  html = Nokogiri::HTML(URI.open(urls[0]).read)
  html.xpath('html/body/div[2]/table/tr/td/a/@title').each do |tag|
    kanji, yomi, code = tag.text.strip.split(/\s/)
    colors << {kanji: kanji, yomi: yomi, code: code}
  end

  html = Nokogiri::HTML(URI.open(urls[1]).read)
  html.xpath('//*[@id="mw-content-text"]/div/table').each.with_index do |table, table_i|
    next if table_i == 0

    table.xpath('tbody/tr').each.with_index do |tr, tr_i|
      next if tr_i == 0

      cells = tr.xpath('td')
      kanji, yomi, code = cells[0].text.strip, nil, cells[4].text.strip.downcase
      colors << {kanji: kanji, yomi: yomi, code: code}

      if cells[5]
        kanji, yomi, code = cells[5].text.strip, nil, cells[9].text.strip.downcase
        colors << {kanji: kanji, yomi: yomi, code: code}
      end
    end
  end

  File.write('colors.json', JSON.pretty_generate(colors.uniq { |c| c[:kanji] }))
  unique_and_sort(JSON.parse(File.read('colors.json')))
end

def generate_image(code, width: 1200, height: 600)
  png = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::TRANSPARENT)

  width.times do |w|
    height.times do |h|
      png[w, h] = ChunkyPNG::Color.rgba(255, 0, 00, 128)
      png[w, h] = ChunkyPNG::Color.parse(code)
    end
  end

  png
end

def twitter_client
  Twitter::REST::Client.new(
      consumer_key: ENV['CONSUMER_KEY'],
      consumer_secret: ENV['CONSUMER_SECRET'],
      access_token: ENV['ACCESS_TOKEN'],
      access_token_secret: ENV['ACCESS_SECRET']
  )
end

def tweet(kanji, code)
  png = generate_image(code)
  filename = 'filename.png'
  png.save(filename, interlace: true)
  twitter_client.update_with_media("#{kanji} #{code}", File.open(filename))
ensure
  File.delete(filename)
end

def tweet_once
  color = generate_colors.first
  tweet(color['kanji'], color['code'])
  puts "#{Time.now} #{color['kanji']}"
end

if __FILE__ == $0
  tweet_once
end

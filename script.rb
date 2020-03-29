require 'open-uri'
require 'nokogiri'
require 'chunky_png'
require 'twitter'

def generate_colors
  if File.exist?('colors.json')
    return JSON.parse(File.read('colors.json'))
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
  JSON.parse(File.read('colors.json'))
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

def tweet(client, kanji, code)
  png = generate_image(code)
  filename = 'filename.png'
  png.save(filename, interlace: true)
  client.update_with_media("#{kanji} #{code}", File.open(filename))
ensure
  File.delete(filename)
end

def main
  colors = generate_colors
  colors.uniq{ |c| c['kanji'] }.shuffle.each.with_index do |color, i|
    tweet(client, color['kanji'], color['code'])
    puts "#{i} #{Time.now} #{color['kanji']}"

    sleep 3600
  end
end

if __FILE__ == $0
  main
end


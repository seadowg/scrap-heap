require 'open-uri'
require 'nokogiri'
require 'json/ext'
require 'sinatra'

module Formats
  JSON = "json"
  SOUNDIIZ_JSON = "soundiiz_json"
end

class DocFetcher
  def fetch(url)
    html = open (url) { |f| f.read }
    Nokogiri::XML(html)
  end
end

class BandcampWishlistData
  def initialize(tracks)
    @tracks = tracks
  end

  def as(format)
    if format == Formats::SOUNDIIZ_JSON
      {
        "title": "Bandcamp Wishlist",
        "tracklist": @tracks
      }.to_json
    else
      @tracks.to_json
    end
  end
end

class BandcampWishlist
  def initialize(doc_fetcher)
    @doc_fetcher = doc_fetcher
  end

  def fetch(username)
    wishlist_doc = @doc_fetcher.fetch("https://bandcamp.com/#{username}/wishlist")
    album_urls = wishlist_doc.xpath("//a[@class='item-link']").map { |a| a.attributes['href'].value }

    all_tracks = album_urls.reduce([]) { |list, url|
      list.concat(get_tracks_for_url(url))
    }

    BandcampWishlistData.new(all_tracks)
  end

  private

  def get_tracks_for_url(url)
    album_doc = @doc_fetcher.fetch(url)

    title = album_doc.at_xpath("/html/head/title").text
    album = title.split('|')[0].strip
    artist = title.split('|')[1].strip

    tracks = album_doc.xpath("//span[@class='track-title']").map { |track| track.text }
    tracks.map { |track|
      {
        "title": track,
        "album": album,
        "artist": artist
      }
    }
  end
end

get '/:service/:data/:identifier' do
  data_fetcher = if params[:service] == "bandcamp"
    if params[:data] == "wishlist"
      BandcampWishlist.new(DocFetcher.new)
    end
  end

  data_fetcher.fetch(params[:identifier]).as(params[:format])
end

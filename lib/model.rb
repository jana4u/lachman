require File.dirname(__FILE__) + '/../vendor/maruku/maruku'

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../vendor/syntax'
require 'syntax/convertors/html'
require 'active_support/inflector'
#require 'image_science'


class ImageUploader < CarrierWave::Uploader::Base
  include CarrierWave::RMagick

  process :resize_to_limit => [620, 620]

  def store_dir
    'uploads'
  end
end

class Picture < Sequel::Model
  plugin :schema
  many_to_one :posts
  
  create_table(:pictures) do
    primary_key :id
    foreign_key :post_id, :posts
		text :filename
		integer :order, :default => 0
		timestamp :created_at
  end unless table_exists?
  
  mount_uploader :filename, ImageUploader
  
end


class Post < Sequel::Model
  plugin :schema
  one_to_many :pictures, :order => :order
  plugin :association_dependencies, :pictures=>:destroy

  create_table(:posts) do
    primary_key :id
    text :title
    text :location
		text :body
		text :slug
		text :category
		text :company
		#text :tags
		#text :avatar
		timestamp :created_at
  end unless table_exists?                      
	

  def before_save
    self.slug = self.class.make_slug(title)
    super
  end

	def url
		# d = created_at
		# "/past/#{d.year}/#{d.month}/#{d.day}/#{slug}/"
		"/#{company}/reference/#{category}/#{slug}/"
	end

	def full_url
		Blog.url_base.gsub(/\/$/, '') + url
	end

	def body_html
		to_html(body)
	end

	def summary
		@summary ||= body.match(/(.{200}.*?\n)/m)
		@summary || body
	end

	def summary_html
		to_html(summary.to_s)
	end

	def more?
		@more ||= body.match(/.{200}.*?\n(.*)/m)
		@more
	end

	def linked_tags
		tags.split.inject([]) do |accum, tag|
			accum << "<a href=\"/past/tags/#{tag}\">#{tag}</a>"
		end.join(" ")
	end

	def self.make_slug(title)
		#title.downcase.gsub(/ /, '_').gsub(/[^a-z0-9_]/, '').squeeze('_')
		ActiveSupport::Inflector.parameterize(title) # requires activesupport
		#slug
	end

	########

	def to_html(markdown)
		out = []
		noncode = []
		code_block = nil
		markdown.split("\n").each do |line|
			if !code_block and line.strip.downcase == '<code>'
				out << Maruku.new(noncode.join("\n")).to_html
				noncode = []
				code_block = []
			elsif code_block and line.strip.downcase == '</code>'
				convertor = Syntax::Convertors::HTML.for_syntax "ruby"
				highlighted = convertor.convert(code_block.join("\n"))
				out << "<code>#{highlighted}</code>"
				code_block = nil
			elsif code_block
				code_block << line
			else
				noncode << line
			end
		end
		out << Maruku.new(noncode.join("\n")).to_html
		out.join("\n")
	end

	def split_content(string)
		parts = string.gsub(/\r/, '').split("\n\n")
		show = []
		hide = []
		parts.each do |part|
			if show.join.length < 100
				show << part
			else
				hide << part
			end
		end
		[ to_html(show.join("\n\n")), hide.size > 0 ]
	end
end



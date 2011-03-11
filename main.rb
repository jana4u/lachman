require 'rubygems'
require 'sinatra'
require 'ruby-debug'

$LOAD_PATH.unshift File.dirname(__FILE__) + '/vendor/sequel'
require 'sequel'

require 'carrierwave'
require 'carrierwave/orm/sequel'

configure do
	Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://lachman.db')

	require 'ostruct'
	Blog = OpenStruct.new(
		:title => 'Lachman news',
		:author => 'Lachman',
		:url_base => 'http://localhost:4567/',
		:admin_password => 'lachman2011',
		:admin_cookie_key => 'cbis_admin',
		:admin_cookie_value => '913ace5851d6d976',
		:disqus_shortname => nil
	)
end

error do
	e = request.env['sinatra.error']
	puts e.to_s
	puts e.backtrace.join("\n")
	"Application error"
end

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'model'

helpers do
	def admin?
		request.cookies[Blog.admin_cookie_key] == Blog.admin_cookie_value
	end

	def auth
		halt [ 401, 'Not authorized' ] unless admin?
	end
	
  def linebreaks(text)
    text.gsub(/[*+]/,'&nbsp;').gsub(/\s/,'<br/>')
  end
	
end



layout 'layout'

### Public

get '/' do
  erb :home, :layout => false
end

get '/posts' do
	posts = Post.reverse_order(:created_at).limit(10)
	erb :index, :locals => { :posts => posts }, :layout => false
end

get '/past/:year/:month/:day/:slug/' do
	post = Post.filter(:slug => params[:slug]).first
	#pics = Picture.filter(:post_id => post.id).order(:order)
	halt [ 404, "Page not found" ] unless post
	@title = post.title
	erb :post, :locals => { :post => post }
end

get '/past/:year/:month/:day/:slug' do
	redirect "/past/#{params[:year]}/#{params[:month]}/#{params[:day]}/#{params[:slug]}/", 301
end

get '/past' do
	posts = Post.reverse_order(:created_at)
	@title = "Archive"
	erb :archive, :locals => { :posts => posts }
end

get '/past/tags/:tag' do
	tag = params[:tag]
	posts = Post.filter(:tags.like("%#{tag}%")).reverse_order(:created_at).limit(30)
	@title = "Posts tagged #{tag}"
	erb :tagged, :locals => { :posts => posts, :tag => tag }
end

get '/feed' do
	@posts = Post.reverse_order(:created_at).limit(20)
	content_type 'application/atom+xml', :charset => 'utf-8'
	builder :feed
end

get '/rss' do
	redirect '/feed', 301
end

### Admin

get '/auth' do
	erb :auth
end

post '/auth' do
	response.set_cookie(Blog.admin_cookie_key, Blog.admin_cookie_value) if params[:password] == Blog.admin_password
	redirect '/'
end

get '/posts/new' do
	auth
	erb :edit, :locals => { :post => Post.new, :url => '/posts' }
end

post '/posts' do
	auth
	#debugger
	#post = Post.new :title => params[:title], :tags => params[:tags], :body => params[:body], :created_at => Time.now, :slug => Post.make_slug(params[:title])
	post = Post.new :title => params[:title], :location => params[:location], :body => params[:body], :created_at => Time.now, :slug => Post.make_slug(params[:title])
	post.save
	params[:image].each do |img|
	  post.add_picture(:filename => img)
  end unless params[:image].nil?
	
	redirect post.url
end

get '/past/:year/:month/:day/:slug/edit' do
	auth
	post = Post.filter(:slug => params[:slug]).first
	halt [ 404, "Page not found" ] unless post
	erb :edit, :locals => { :post => post, :url => post.url }
end

post '/past/:year/:month/:day/:slug/' do
	auth
	#debugger
	post = Post.filter(:slug => params[:slug]).first
	halt [ 404, "Page not found" ] unless post
	post.title = params[:title]
	post.tags = params[:tags]
	post.body = params[:body]
	#post.avatar = params[:avatar]
	post.save
	#post.remove_all_pictures #TODO better have delete button for each separate image
	params[:image].each_with_index do |img,index|
	  post.add_picture(:filename => img, :order => post.pictures.last.order+index+1)
  end unless params[:image].nil?
	
	redirect post.url
end

post '/reorder' do
  #debugger
  params[:pic].each_with_index do |pic_id,index|
    pic = Picture[:id => pic_id.to_i]
    #puts pic
    pic.set(:order => index)
    pic.save
  end
end

delete '/pictures/:id' do
  Picture[params[:id]].destroy
  redirect back
end

# LACHMAN:
get '/reference/new' do
	auth
	erb :edit, :locals => { :post => Post.new, :url => '/reference' }
end

get '/:company/reference' do
  redirect "/#{params[:company]}/reference/vsechny", 301
end

get '/:company/reference/' do
  redirect "/#{params[:company]}/reference/vsechny", 301
end

get '/:company/reference/:category' do
  case params[:category]
  when 'vsechny'
	  posts = Post.reverse_order(:created_at).limit(10)
	when 'banky', 'verejne-budovy', 'kancelare-a-obchodni-prostory', 'hotely-a-restaurace', 'rodinne-domy-a-byty'
	  posts = Post.filter(:category => params[:category]).reverse_order(:created_at).limit(10)
  else
    halt [404,"No such category"]
  end
  erb :credentials_list, :locals => { :posts => posts }, :layout => false
end

post '/reference' do # create new reference
	auth
	post = Post.new :title => params[:title], 
	                :location => params[:location], 
	                :body => params[:body], 
	                :created_at => Time.now, 
	                :slug => Post.make_slug(params[:title]),
	                :category => params[:cat],
	                :company => params[:company] 
	post.save
	params[:image].each_with_index do |img,index|
	  post.add_picture(:filename => img, :order => index)
  end unless params[:image].nil?
	
	redirect post.url
end

get '/:company/reference/:category/:slug/' do
  case params[:category]
  when 'vsechny', 'banky', 'verejne-budovy', 'kancelare-a-obchodni-prostory', 'hotely-a-restaurace', 'rodinne-domy-a-byty'
    post = Post.filter(:slug => params[:slug]).first
  	halt [ 404, "Page not found" ] unless post
  	@title = post.title
  	erb :credential, :locals => { :post => post }, :layout => false
	else
	  halt [ 404, "No such category" ]
	end
end

get '/:company/reference/:category/:slug' do
	redirect "/reference/#{params[:slug]}/", 301 # take care of the trailing slash
end

get '/:company/reference/:category/:slug/edit' do
	auth
	post = Post.filter(:slug => params[:slug]).first
	halt [ 404, "Page not found" ] unless post
	erb :edit, :locals => { :post => post, :url => post.url }
end

post '/:company/reference/:category/:slug/' do
	auth
	#debugger
	post = Post.filter(:slug => params[:slug]).first
	halt [ 404, "Page not found" ] unless post
	post.title = params[:title]
	post.location = params[:location]
	post.body = params[:body]
	post.category = params[:cat]
	post.company = params[:company]
	post.save
	params[:image].each_with_index do |img,index|
	  post.add_picture(:filename => img, :order => post.pictures.last ? post.pictures.last.order+index+1 : index)
  end unless params[:image].nil?
	
	redirect post.url
end

delete '/reference/:id' do
  Post[params[:id]].destroy
  redirect '/reference'
end



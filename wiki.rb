require 'lib/init'

if PASSWORD_PROTECTED
  use Rack::Auth::Basic do |username, password|
    [username, password] == [USER, PASSWORD]
  end
end

helpers do
  def md(s)
    BlueCloth.new(s).to_html
  end
  def zebra(val)
    @_zebra = true unless defined?(@_zebra)
    (@_zebra = !@_zebra) ? val : ""
  end
end

configure do
  set :root, File.dirname(__FILE__)
  enable :inline_templates
  set :translations, './locales'
end

before do
  content_type :html, 'charset' => 'utf-8'
  session[:locale] = LOCALE
  @title = ""
end

get '/p' do
  @pages = Page.scoped(:order => "updated_at desc").all
  @title = t.listofpages.capitalize
  haml :pages
end

post '/p' do
  if params[:page_id] && params[:page_id].to_i > 0
    @page = Page.find(params[:page_id])
    @page.locked_at = nil
    if params[:version]
      @page.revert_to!(params[:version].to_i)
      redirect @page.url
    elsif @page.update_attributes(params[:page])
      redirect @page.url
    else
      @title = t.editpage
      haml :form
    end
  else
    @page = Page.new(params[:page])
    @page.locked_at = nil
    if @page.save
      redirect @page.url
    else
      @title = t.newpage.capitalize
      haml :form
    end
  end
end

delete '/p' do
  @page = Page.find(params[:page_id])
  if @page
    @page.destroy
  end
  redirect '/'
end

post '/r' do
  url = params[:url]
  @page = Page.find_by_url(url)
  if @page
    @page.skip_version do
      @page.locked_at = Time.now
    end
  end
end

get '/n' do
  @page = Page.new(params[:page])
  @title = t.newpage.capitalize
  haml :form
end

get '/e/*' do
  url = "/#{params[:splat]}"
  @page = Page.find_by_url(url)
  if @page
    unless @page.locked?
      @page.skip_version do
        @page.locked_at = Time.now
      end
      @title = t.editpage.capitalize
      haml :form
    else
      redirect @page.url
    end
  else
    redirect '/'
  end
end

get '*' do
  @url = params[:splat]
  @page = Page.find_by_url(@url)
  if @page
    @page.revert_to(params[:version].to_i) if params[:version]
    @title = @page.title
    haml :page
  else
    @title = t.notfound
    haml :not_found
  end
end

require "rubygems"
require "sinatra"
require "i18n"
require "indextank"
require "open-uri"
require "nokogiri"
require "sinatra/content_for"

use Rack::Session::Cookie

set :views, File.dirname(__FILE__) + "/templates"

# Loading locales
Dir.glob("i18n/*.yml").each { |locale| I18n.load_path << locale}
I18n.locale = "pt-BR"

before do
  if params[:lang]
    set_locale(params[:lang])
  end
end

# HOME
get "/" do redirect "/#{current_locale}/termos" end

navigation = [
# Termos de Uso Portalde Compras
  { "url" => "termos",                           "view_path" => "termos/index"},
]

navigation.each do |item|
  get "/#{item["url"]}" do redirect "/#{current_locale}/#{item["url"]}", 303 end
  get "/:locale/#{item["url"]}" do |locale|
    if params[:lang]
      set_locale(params[:lang])
    else
      set_locale(locale)
    end
    erb "#{item["view_path"]}".to_sym
  end
end

# COMMANDS DESCRIPTIONS
commands = [
  # flow
  "if", "else", "while", "break", "function", "callfunction", "execute", "exit",
  # readcard
  "getcardvariable", "system.readcard", "system.inputtransaction",
  # ui
  "menu", "menuwithheader", "displaybitmap", "display", "cleandisplay", "system.gettouchscreen",
  # print
  "print", "printbig", "printbitmap", "printbarcode", "checkpaperout", "paperfeed",
  # input
  "inputfloat", "inputformat", "inputinteger", "inputoption", "inputmoney",
  # crypto
  "crypto.crc", "crypto.encryptdecrypt", "crypto.lrc", "crypto.xor",
  # file
  "downloadfile", "filesystem.filesize", "filesystem.listfiles", "filesystem.space", "file.open", "file.close", "file.read", "file.write", "readfile", "readfilebyindex", "editfile", "deletefile",
  # iso
  "iso8583.initfieldtable", "iso8583.initmessage", "iso8583.putfield", "iso8583.endmessage", "iso8583.transactmessage", "iso8583.analyzemessage", "iso8583.getfield",
  # serialport
  "openserialport", "writeserialport", "readserialport", "closeserialport",
  # datetime
  "getdatetime", "time.calculate", "adjustdatetime",
  # conectivity
  "predial", "preconnect", "shutdownmodem", "network.checkgprssignal", "network.hostdisconnect", "network.ping", "network.send", "network.receive",
  # pinpad
  "pinpad.open", "pinpad.loadipek", "pinpad.getkey", "pinpad.getpindukpt", "pinpad.display", "pinpad.close",
  # emv
  "emv.open", "emv.loadtables", "emv.cleanstructures", "emv.adddata", "emv.getinfo", "emv.inittransaction", "emv.processtransaction", "emv.finishtransaction", "emv.removecard", "emv.settimeout", "system.readcard", "system.inputtransaction",
  # variables
  "integervariable", "stringvariable", "integerconvert", "convert.toint", "inttostring", "stringtoint", "integeroperator", "string.tohex", "string.fromhex",
  # string
  "string.charat", "string.elementat", "string.elements", "string.find", "string.getvaluebykey", "string.trim", "string.insertat", "string.length", "string.pad", "string.removeat", "string.replace", "string.replaceat", "string.substring", "substring", "joinstring", "input.getvalue",
  # smartcard
  "smartcard.insertedcard", "smartcard.closereader", "smartcard.startreader", "smartcard.transmitapdu",
  # utils
  "mathematicaloperation", "system.beep", "system.checkbattery", "system.info", "system.restart", "unzipfile", "waitkey", "waitkeytimeout", "readkey", "wait"
]

commands.each do |command|
  get "/posxml/commands/#{command}" do redirect "/#{current_locale}/posxml/commands/#{command}", 303 end
  get "/:locale/posxml/commands/#{command}" do |locale|
    if params[:lang]
      set_locale(params[:lang])
    else
      set_locale(locale)
    end
    erb "posxml/commands/#{command}".to_sym
  end
end

get "/searchify" do searchify(commands, navigation) end

get "/:locale/search" do
  set_locale(params[:locale])
  client = IndexTank::Client.new(ENV["SEARCHIFY_API_URL"] || "http://:P1gXpRxYmDVbG2@28z3j.api.searchify.com")
  index = client.indexes("cloudwalk-docs")

  if params[:query]
    query = "(title:(#{params[:query]})^5 OR text:(#{params[:query]})) AND language:#{current_locale}"
  else
    redirect "/#{current_locale}/overview"
  end

  @results = index.search(query,
                         :fetch => 'title, description, url')
  erb :search
end

not_found do
  erb :not_found
end

# Helpers
def set_locale(locale)
  if I18n.available_locales.include?(locale.to_sym)
    session[:locale] = locale
    return I18n.locale = locale
  end

  redirect request.fullpath.gsub("/#{locale}/", "/#{current_locale}/")
end

def current_locale
  session[:locale].nil? ? "pt-BR" : session[:locale]
end

def link_to(name, url)
  "<a href='/#{current_locale}/#{url}'>#{name}"
end

def is_group_active?(group)
  "in" if group == request.path_info.split("/")[2]
end

def is_group_item_active?(group, item=nil)
  if group == request.path_info.split("/")[2]
    return "class='active'" if request.path_info.split("/").length == 3 && item.nil?
    return "class='active'" if item == request.path_info.split("/").last
  end
end

def option_select(value, text)
  selected = session[:locale] == value ? ' selected' : ''
  "<option value=#{value}#{selected}>#{text}</option>"
end

def mootit
  command = uri.split('/').last
  "<a class='moot' data-label='#{I18n.t("posxml.commands.comments_message")}' href='https://moot.it/i/cloudwalk/docs/#{command}'></a>"
end

def search_result(results)
  result_erb = ""
  if results["matches"] > 0
    result_erb = "<ul class='search-listing'>"
    results['results'].each do |doc|
      docid = doc['docid']
      title = doc['title']
      description = doc['description']
      url = doc['url']
      result_erb << "<li><a href='#{url}'>#{title.upcase}</a><p class='muted'>#{description}</p></li>"
    end
    result_erb << "</ul>"
  else
    result_erb = "<p>#{I18n.t("general.search_with_no_results", :query => params[:query])}</p>"
  end
  result_erb
end

# Create indexes for searchify
def searchify(commands, navigation)
  client = IndexTank::Client.new(ENV['SEARCHIFY_API_URL'] || 'http://:P1gXpRxYmDVbG2@28z3j.api.searchify.com')
  @index = client.indexes('cloudwalk-docs')

  commands.each do |command|
    puts "Command en #{command}\n"
    response = load_page("en", command, "commands")

    puts "Command pt-BR #{command}\n"
    load_page("pt-BR", command, "commands")
  end

  navigation.each do |nav|
    puts "Navigation en #{nav['url']}\n"
    load_page("en", nav['url'])

    puts "Navigation pt-BR #{nav['url']}\n"
    load_page("pt-BR", nav['url'])
  end

end

def load_page(language, item, block = nil)
  url = block == "commands" ? "http://docs.cloudwalk.io/#{language}/posxml/commands/#{item}" : "http://docs.cloudwalk.io/#{language}/#{item}"

  page = Nokogiri::HTML(open(url))
  description = page.css("meta[name='docs:description']").first

  item = block == "commands" ? item.gsub(".", "") : item.gsub("-", " ").gsub("/", " ") # Need to remove - to make searchify more precise

  @index.document("#{item} #{language}").add({
    text: "#{page.css("div.span9").first}",
    title: "#{item}",
    description: "#{description["content"]}",
    url: "#{url}",
    language: "#{language}"
  })
end

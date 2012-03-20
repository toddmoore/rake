desc "Set up a Twitter Bootstrap project"
task :newtwitter => [:init] do
  `git clone https://github.com/twitter/bootstrap.git`
  `mv ./bootstrap/js/*.js ./js/`
  `mv ./bootstrap/img/* ./images/`
  `mv ./bootstrap/docs/assets/ico/* ./`
  `cd bootstrap/less && lessc bootstrap.less > ../../css/bootstrap.css`
  `sed -i '.old' 's@/img@/images@g' css/bootstrap.css && mv css/bootstrap.css css/bootstrap.css`
  `rm -rf bootstrap`
  `touch index.html`
  Rake::Task['gitinit'].invoke
end

desc "Set up an HTML5 Boilerplate project"
task :newhtml5 => [:init] do
  `rm -rf ./css`
  `rm -rf ./js`
  `git clone https://github.com/h5bp/html5-boilerplate.git`
  `mv ./html5-boilerplate/* ./`
  `mv ./html5-boilerplate/.gitattributes ./.gitattributes`
  `mv ./html5-boilerplate/.gitignore ./.gitignore`
  `mv ./html5-boilerplate/.htaccess ./.htaccess`
  `rm ./.htaccess`
  `rm -rf ./img`
  `rm ./readme.md`
  `rm ./robots.txt`
  `rm ./humans.txt`
  `rm ./404.html`
  `mv apple-touch-icon* ./images`
  `mv favicon.ico ./images`
  `touch css/application.css`
  `rm -rf html5-boilerplate`
  Rake::Task['gitinit'].invoke
end

desc "Set up a new Email Template Project"
task :newemail do
  `git clone https://github.com/seanpowell/Email-Boilerplate.git .`
  `rm ./README.markdown`
  `rm ./contributors.txt`
  `rm ./email.html`
  `mv ./email_lite.html ./email.html`
  Rake::Task['gitinit'].invoke
end

desc "Grab flat file server from git and bundle install it"
task :grab_flat_server do
  `git clone git@github.com:dtdigital/flat_file_sinatra_server.git`
  Dir.chdir("./flat_file_sinatra_server")
  Dir['*'].each do |file|
    system %Q{mv "#{file.sub('.erb', '')}" "../"}
  end
  Dir.chdir("../")
  `rm -rf flat_file_sinatra_server`
  `bundle install`
end

desc "Create dt config file"
task :dtconfig do
      yaml = %q{
config:
  path_to_file_server: ""
  assets_folder_name: "assets"

folders:
  css: "css"
  images: "images"
  js: "js"
      }

      config = File.new("./dt.yaml", "w")
      config.write(yaml)
      config.close
end


#TODO: Add the default sinatra config and app stuff from the dtdigital org github
desc "Create new flat file project for OSX and assign some variables"
task :newproject do
  print "Project Job Number: "

  if (project = $stdin.gets.chomp)

    path = File.join(Dir.getwd, project)

    if Dir.exists? path
      puts "ERROR: Directory already exists, exiting...."
    else
      `mkdir #{path}`
      Dir.chdir(path)

      Rake::Task['dtconfig'].invoke
      Rake::Task['newhtml5'].invoke

      system %Q{mkdir "./assets"}
      system %Q{mv "./css" "./assets/css"}
      system %Q{mv "./images" "./assets/images"}
      system %Q{mv "./js" "./assets/javascript"}
      system %Q{mv "./coffee" "./assets/coffee"}

      Rake::Task['grab_flat_server'].invoke

      print "Do you want to open the Project up in Sublime: [yn] "
      case $stdin.gets.chomp
      when 'y'
        `subl .`
      when 'n'
        false
      end

    end
  end
end

desc "Package up flat file project and place on fileserver"
task :package_project do
  require 'yaml'
  # #
  # TODO: Move the current directory contents into old
  # Copy over the new directory
  # 

  @localDirectory = Dir.getwd
  @date = Time.new
  @config = YAML.load_file("dt.yaml")
  @path_parent = @config["config"]["path_to_file_server"]

  def make_current_working_directory()
    _p = "#{@path_parent}/#{@date.strftime("%Y%m%d")}"
    system %Q{mkdir "#{_p}"}
    package_and_copy_current_directory(_p)
  end

  def package_and_copy_current_directory(_p)
    Dir.chdir(@localDirectory)
    assets_folder = @config["config"]["assets_folder_name"]
    
    #TODO: make this a dynamic loop, so that the folders can be (n)

    css = @config["folders"]["css"]
    images = @config["folders"]["images"]
    js = @config["folders"]["js"]

    system %Q{cp -r "./#{assets_folder}/#{css}" "#{_p}"}
    system %Q{cp -r "./#{assets_folder}/#{images}" "#{_p}"}
    system %Q{cp -r "./#{assets_folder}/#{js}" "#{_p}"}
    system %Q{cp -r "./index.html" "#{_p}"}
  end

  if Dir.exists? "#{@path_parent}/#{@date.strftime("%Y%m%d")}"  
    if not Dir.exists? "#{@path_parent}/_old"
      system %Q{mkdir "#{@path_parent}/_old"}
    end

    Dir.chdir(@path_parent)
    Dir['*'].each do |file|
      if File.basename(file) != "_old"
        if /(20)\d{6}/.match(File.basename(file))
          if Dir.exists? "#{Dir.getwd}/_old/#{File.basename(file)}"
            # add in incrementing underscores
            Dir.chdir("./_old")
            increment = 0
            Dir['*'].each do |old_files|
              array = old_files.split("_")
              if File.basename(file).to_s == array[0].to_s
                increment += 1
              end
            end
            Dir.chdir("../")
            system %Q{mv "#{file.sub('.erb', '')}" "./_old/#{file.sub('.erb', '')}_#{increment}"}
          else
            system %Q{mv "#{file.sub('.erb', '')}" "./_old/#{file.sub('.erb', '')}"}
          end
        end
      end
    end

    make_current_working_directory()

  else 
    make_current_working_directory()
  end
end

desc "Compile non inline styles to inline styles for eDMs"
task :toinline do

  require 'net/http'
  require 'cgi'

  if File.exist?("email.html")
    email = File.open("email.html", "rb")
    email_content = email.read

    #uses the http://inlinestyler.torchboxapps.com web service
    uri = URI('http://inlinestyler.torchboxapps.com/styler/convert/')
    req = Net::HTTP::Post.new(uri.path)
    req.set_form_data('source' => email_content, 'returnraw' => true)

    res = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      html = CGI.unescapeHTML(res.body)
      if File.exist?("email_compiled.html")
        system %Q{rm "email_compiled.html"}
      end
      
      file = File.new("email_compiled.html", "w")
      file.write(html)
      file.close

    else
      res.value
      puts "ERROR: inline service returned #{res.value}"
    end
  else
    puts "ERROR: missing an email template named 'email.html'"
  end

end

desc "Set up a blank project"
task :newblank => [:init] do
  `touch index.html`
  Rake::Task['gitinit'].invoke
end

desc "Create git repository"
task :gitinit do
  `git init . && git add . && git commit -m "Initial Commit."`
end

desc "Initialize project structure"
task :init do
  `mkdir coffee css images js`
  `touch coffee/application.coffee`
  `touch css/application.css`
end

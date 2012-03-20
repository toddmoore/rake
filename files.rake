desc "Remove duplicate images files"
task :remove_duplicates, :directory do |t, args|
		
	# deduplicate_files.rb
	 
	require 'rubygems'
	require 'sqlite3' # Look at 'http://github.com/luislavena/sqlite3-ruby' then do 'sudo gem install sqlite3-ruby'
	require 'digest/sha1'
	require 'pathname'
	 
	# Pass in the directory or assume the current one.
	arg = args.directory || "."
	root_path = Pathname.new(arg).realpath.to_s
	puts "Examining #{root_path}"
	 
	# Create a SQLite3 database in the current directory.
	system %Q{rm "deduplicate_files.db"}
	db = SQLite3::Database.new("deduplicate_files.db")
	db.execute("create table files(digest varchar(40),path varchar(1024))")
	 
	# Recursively generate hash digests of all files.
	Dir.chdir("#{root_path}")
	current_file = 0
	Dir['**/*.*'].each do |file|
	  path = "#{root_path}/#{file}"
	  # Ignore non-existent files (symbolic links) and directories.
	  next if !File.exists?("#{path}") || File.directory?("#{path}")
	  # Create a hash digest for the current file.
	  digest = Digest::SHA1.new
	  File.open(file, 'r') do |handle|
	    while buffer = handle.read(1024)
	      digest << buffer
	    end
	  end
	  # Store the hash digest and full path in the database.
	  db.execute("insert into files values(\"#{digest}\",\"#{path}\")")
	  # Print out every Nth file.
	  puts "[#{digest}] #{path} (#{current_file})" if current_file % 100 == 0
	  current_file = current_file + 1
	end
	 
	# Loop through digests.
	db.execute("select digest,count(1) as count from files group by digest order by count desc").each do |row|
	  if row[1] > 1 # Skip unique files.
	    puts "Duplicates found:"
	    digest = row[0]
	    
	    # List the duplicate files.
	    db.execute("select digest,path from files where digest='#{digest}'").each_with_index do |dup_row, index|
	      puts "[#{digest}] #{dup_row[1]}"
	      if index == 0
	      	system %Q{rm "#{dup_row[1]}"}
	      end
	   end
	 end
	end

	system %Q{rm "deduplicate_files.db"}

end


desc "Batch rename files based on a separator args [current_string, string_to_rename, separator]"
task :rename_files_with_seperator, :current_string, :string_to_rename, :separator do |t, args|
	
	current_string = args.current_string || ""
	seperator = args.seperator || "-"
	string_to_rename = args.string_to_rename || ""

	Dir['*'].each do |file|

		file_array = File.basename(file).split(seperator) 

		next if file_array[0] != current_string

		if File.exist?("./#{string_to_rename}-#{file_array[1]}")
			system %Q{mv "./#{file.sub('.erb', '')}" "#{string_to_rename}-#{file_array[1]}"}
		else
			system %Q{mv "./#{file.sub('.erb', '')}" "#{string_to_rename}-#{file_array[1]}"}
		end

	end
end



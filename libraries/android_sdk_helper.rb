require 'pty'  
require 'expect'  

module AndroidSdkHelper

  @@all_packages = []
  @@installed_packages_checked = false

  #build up a data structure of packages
  def get_packages
    #only fetch them once
    if !@@all_packages.empty?
      return @@all_packages
    end
    puts "      - fetching a list of all available android sdk packages from remote repositories"
    ENV['ANDROID_HOME'] = @new_resource.android_home
    android_bin = @new_resource.android_bin
    package = Hash.new  
    begin  
      PTY.spawn("#{android_bin} list sdk --extended --all") do |stdout, stdin, pid|  
        begin  
          stdout.each do |line|  
            #print line  
            if line =~/----------/  
              package = Hash.new  
            elsif line =~/id:/  
              package["id"] = line.split(":")[1].strip!  
            elsif line =~/Type:/  
              package["Type"] = line.split(":")[1].strip!  
            elsif line =~/Desc:/  
              package["Description"] = line.split(":")[1].strip!  
              package["Installed"] = false #we'll check this later
              @@all_packages.push(package)  
            end  
          end  
        rescue Errno::EIO  
        ensure  
          Process.wait(pid)  
        end  
      end  
    rescue PTY::ChildExited  
      raise "DED"  
      puts "The child process exited!"  
    end  
    status = $?  
    if status == 0  
      puts "      - Done fetching a list of all available android sdk packages from remote repositories"
    else  
      raise "      - FAILED fetching a list of all available android sdk packages from remote repositories exit code #{status}!"  
    end  
    @@all_packages
  end


  #without checking installed_packages, this will reinstall
  def install_packages(pattern, android_home, android_bin)

    find_installed_packages() unless @@installed_packages_checked

    matches = get_packages().select do |p|
      #todo move installed check to seprate check, because we want to raise if 0 matches
      p["Description"] =~ Regexp.new(pattern) && p["Installed"] == false
    end

    if matches.empty?
      puts "        - SKIPPING: all android sdk packages that match the parttern '#{pattern}' are already installed"
      return 0
    end
    
    ids = [];
    matches.each do |match|
      ids.push(match ["id"].split(' ')[0])
    end

    raise if ids.empty?

    ENV['ANDROID_HOME'] = android_home

    ids.each do |id|
      begin
        #maybe sudo -u node['android-sdk']['owner']
        puts "#{android_bin} update sdk --no-ui --all --filter #{id}"
        PTY.spawn("#{android_bin} update sdk --no-ui --all --filter #{id} 2>&1") do |stdout, stdin, pid|
          begin
            # Do stuff with the output here. Just printing to show it works
            stdout.expect(Regexp.new("Do you accept the license *")) do |result|
                stdin.puts("y\n")
            end
            stdout.each do |line| 
              print line 
            end
          rescue Errno::EIO
          ensure
            Process.wait(pid)
          end
        end
      rescue PTY::ChildExited
        raise "DED"
        puts "The child process exited!"
      end
      status = $?
      if status == 0
          puts "Done!"
      else
        raise "Failed with exit code #{status}!"
      end
    end

  end

  def find_installed_packages
    Dir[ @new_resource.android_home + "/**/source.properties" ].each do |properties_file|
      properties = Hash.new
      ::File.open(properties_file).each do |line|
          next if line =~ /^#/
          key,value = line.split(/=/)
          properties[key] = value.gsub("\n",'')
      end
      #check what type of package it is based on the path
      android_home_subdir =  ::File.path(properties_file)
        .gsub(@new_resource.android_home + '/','')
        .split("/").first
    
      unless  properties.has_key?("Pkg.Revision")
        #todo: more specific error message
        raise "properties file is missing one of the required keys" 
      end

      package_description = nil

      if android_home_subdir == "platform-tools"
        package_description = "Android SDK Platform-tools, revision " +
          properties["Pkg.Revision"]
      elsif android_home_subdir == "tools"
        package_description = "Android SDK Tools, revision " +
          properties["Pkg.Revision"]
      elsif android_home_subdir == "build-tools"
        package_description = "Android SDK Build-tools, revision " +
          properties["Pkg.Revision"]
      elsif android_home_subdir == "platforms"
        unless  properties.has_key?("AndroidVersion.ApiLevel") &&
            properties.has_key?("Pkg.Revision") &&
            properties.has_key?("Platform.Version")
          #todo: more specific error message
          raise "properties file is missing one of the required keys" 
        end
        package_description = "SDK Platform Android " + properties["Platform.Version"] +
      ", API " + properties["AndroidVersion.ApiLevel"] +
      ", revision " + properties["Pkg.Revision"]
      elsif android_home_subdir == "add-ons"
        package_description = properties['Addon.NameDisplay'] + "," +
            "API " + properties['AndroidVersion.ApiLevel'] + ","+
            "revision " + properties['Pkg.Revision']
      elsif android_home_subdir == "extras"
        unless  properties.has_key?("Pkg.Revision") &&
            properties.has_key?("Extra.NameDisplay")
          #todo: more specific error message
          raise "properties file is missing one of the required keys" 
        end
        package_description = properties["Extra.NameDisplay"] +
          ", revision "+properties["Pkg.Revision"].gsub(".0.0",'')
      else
        raise "UNKNOWN SDK SUBDIR '#{android_home_subdir}' , #{properties_file}"
      end

      #TODO use collect!
      #todo is there a way to mutate while iterating?, is that a bad idea?
      indicies = get_packages().each_index.select do |index| 
        get_packages()[index]["Description"] =~  Regexp.new(package_description) 
      end
    
      #this doesn't account for installed but no longer available
      indicies.each do |index|
        get_packages()[index]["Installed"] = true unless index.nil?
      end
    end

  end

end


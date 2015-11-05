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
    Chef::Log.info "fetching a list of all available android sdk packages from remote repositories"
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
      Chef::Log.error "fetching a list of android packages from the 'android' command failed!"
    end  
    status = $?  
    if status == 0  
      Chef::Log.info "Done fetching a list of all available android sdk packages from remote repositories"
    else  
      raise "FAILED fetching a list of all available android sdk packages from remote repositories exit code #{status}!"
    end  
    @@all_packages
  end


  #without checking installed_packages, this will reinstall
  def install_packages(pattern, android_home, android_bin)

    find_installed_packages() unless @@installed_packages_checked
    matches = get_packages().select do |p|
      p["Description"] =~ Regexp.new(pattern)
    end

    if matches.empty?
      raise  "FAILED: the remote android sdk repository does not have any packages that match the parttern '#{pattern}'"
    end

    matches.select! do |p|
      p["Installed"] == false
    end

    if matches.empty?
      Chef::Log.info "SKIPPING: all android sdk packages that match the parttern '#{pattern}' are already installed"
      return 0
    end
    
    ids = [];
    matches.each do |match|
      ids.push(match ["id"].split(' ')[0])
    end
    raise "FUCK!" if ids.empty?

    ENV['ANDROID_HOME'] = android_home

    ids.each do |id|
      begin
        #maybe sudo -u node['android-sdk']['owner']
        Chef::Log.info "#{android_bin} update sdk --no-ui --all --filter #{id}"
        PTY.spawn("#{android_bin} update sdk --no-ui --all --filter #{id} 2>&1") do |stdout, stdin, pid|
          begin
            # Do stuff with the output here. Just printing to show it works
            stdout.expect(Regexp.new("Do you accept the license*")) do |result|
                Chef::Log.info "ACCEPTING LICENCE"
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
        raise "The child process being used to update the android sdk exited unexpectedly!"

      end
      status = $?
      if status == 0
          Chef::Log.info "The child processes being used to update the android sdk is done"
      else
        raise "The child processes being used to update the android sdk Failed with exit code #{status}!"
      end
    end
    puts "end: install_packages"
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
        raise "properties file: '#{properties_file}' is missing one of the required keys: 'Pkg.Revision'" 
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
            properties.has_key?("Pkg.Desc") &&
            properties.has_key?("Platform.Version")
          raise "properties file: '#{properties_file}' is missing one of the required keys"
        end
        package_description = properties["Pkg.Desc"]
      elsif android_home_subdir == "add-ons"
        package_description = properties['Addon.NameDisplay'] + "," +
            "API " + properties['AndroidVersion.ApiLevel'] + ","+
            "revision " + properties['Pkg.Revision']
      elsif android_home_subdir == "extras"
        unless  properties.has_key?("Pkg.Revision") &&
            properties.has_key?("Extra.NameDisplay")
          raise "properties file: '#{properties_file}' is missing one of the required keys"
        end
        package_description = properties["Extra.NameDisplay"] +
          ", revision "+properties["Pkg.Revision"].gsub(".0.0",'')
      elsif android_home_subdir == "system-images"
        unless properties.has_key?("Pkg.Desc") 
          raise "properties file: '#{properties_file}' is missing one of the required keys"
        end
        package_description = properties["Pkg.Desc"]
      else
        raise "UNKNOWN SDK SUBDIR '#{android_home_subdir}' , #{properties_file}"
      end

      #mark matching installed packages as installed
      get_packages().collect! do |p|
        if p["Description"] =~  Regexp.new(package_description) 
          p["Installed"] = true 
        end
        p
      end
      #if there was no matches, that means that something was 
      #installed that is no longer in the remote repo
      not_fonud = get_packages().select do |p|
        p["Description"] =~  Regexp.new(package_description) 
      end.length == 0
      Chef::Log.warn "package '#{package_description}' is installed but no longer in the remote repository!" if not_fonud
    end

  end

end


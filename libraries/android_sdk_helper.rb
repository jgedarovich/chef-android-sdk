require 'pty'  
require 'expect'  

module AndroidSdkHelper

  @@all_packages = []
  @@installed_platform_tools = [];

  #build up a data structure of packages
  def get_packages
    #only fetch them once
    if !@@all_packages.empty?
      return @@all_packages
    end
    puts "fetching a list of all android sdk packages"
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
        puts "Done fetching a list of all android sdk packages!"  
    else  
      raise "Failed fetching a list of all android sdk package, exit code #{status}!"  
    end  
    @@all_packages
  end


  #without checking installed_packages, this will reinstall
  def install_package(pattern, android_home, android_bin)

    id = get_packages().select do |p|
      p["Description"] =~ Regexp.new(pattern)
    end.first["id"].split(' ')[0]

    raise if id.nil?

    ENV['ANDROID_HOME'] = android_home
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


  def get_current_installed_platform_tools
    #only fetch them once
    if !@@installed_platform_tools.empty?
      return @@installed_platform_tools
    end
    properties = Hash.new
    platform_tools_properties_file = @new_resource.android_home + "/platform-tools/source.properties"
    #::File is required for chef
    if ::File.exist?( platform_tools_properties_file )
      ::File.open( platform_tools_properties_file ).read.each_line do |line|
        key,value = line.split(/=/)
        properties[key] = value
      end
      unless  properties.has_key?("Pkg.Revision")
        raise "properties file is missing one of the required keys" 
      end
      #the below makes it look like what 'android sdk list --all' would spit out
      package_description = "Android SDK Platform-tools, revision " + properties["Pkg.Revision"].gsub("\n",'')
      @@installed_platform_tools.push(package_description)

      #todo this assumes only one matches
      ind = get_packages().find_index do |package| 
        package["Description"] =~  Regexp.new(package_description) 
      end
      get_packages()[ind]["Installed"] = true

    end
    return @@installed_platform_tools
  end

  def list_available_platform_tools
    get_packages().select do |package|
      package["Type"] =~ /PlatformTool/
    end
  end

  def already_installed(pattern)
    installed = get_installed_packages().inject(false) do |acc,installed_package| 
      acc || installed_package["Description"]==pattern
    end
    installed
  end

  def get_installed_packages
    get_current_installed_platform_tools()
    get_packages().select do |package| 
      package["Installed"] == true
    end
  end



end


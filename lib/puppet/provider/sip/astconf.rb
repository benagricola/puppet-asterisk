require 'puppet/provider/sip'
require 'facter'
require 'inifile'



Puppet::Type.type(:sip).provide :astconf, :parent=> Puppet::Provider::Sip do
  include Puppet::Util::Sip

  @doc = "Sip provider manages SIP config in from sip.conf file"
  has_feature :astconf
  confine :true => true

  def create
    debug 'Creating extension %s' % resource[:name]
  end

  def delete
    debug 'Deleting rule %s' % resource[:name]
    pre =  IniFile.load(self.class.config_file)
    pre.delete_section(resource[:name])
    pre.write(:filename => self.class.config_file)
  end

  def flush
    ini = resource_to_ini
    sip_conf = IniFile.load(self.class.config_file)
    if sip_conf.nil? || sip_conf.sections.empty?
      debug "[new file]"
      ini.write(:filename => self.class.config_file)
    else
      debug "[Merging]"
      merged = sip_conf.merge(ini)
      debug "Containing #{sip_conf}"
      merged.write(:filename => self.class.config_file)
    end
    @property_hash.clear
  end

  def exists?
    debug '[checking for existance]'
    properties[:ensure] == :present

    sip_conf = IniFile.load(self.class.config_file)
    if sip_conf.nil?
      return false
    end
    return sip_conf.has_section?(resource[:name])
  end

  def self.instances
    debug "[instances]"
    extensions =  []
    a = config_file
    debug "[config file #{a} ]"
    sip_conf = IniFile.new(:filename => a)
    arg_config = Hash.new()
    sip_conf.each_section do |section|
      arg_config[:name] = section
      sip_conf[section].each do |key,value|
        arg_config[key.to_sym] = value
      end
      extensions << new(arg_config)
    end
    return extensions
  end

  def self.prefetch(resources)
    debug "[prefetching...]"
    extensions = instances
    resources.keys.each do |name|
      if provider = extensions.find{ |ext| ext.name == name}
        resources[name].provider = provider
      end
    end
  end


  #need to create this accessor method to be able to mock it and test easier. must find a better way.
  def self.config_file
    return '/etc/asterisk/sip.conf'
  end

  def resource_to_ini
    entry = IniFile.new
    tmp = resource.original_parameters.clone
    #inifile returns keys as strings not symbols, we should do the same.
    tmp.keys.each do |key|
      tmp[(key.to_s rescue key) || key] = tmp.delete(key)
    end
    entry[resource[:name]] = tmp
    debug "#{entry}"
    entry
  end


  #method_missing was broken by issue http://projects.puppetlabs.com/issues/10915
  #must include this ugly fix
  %w(accountcode allow disallow allowguest amaflags astdb auth callerid busylevel callgroup callingpres canreinvite cid_number context defaultip defaultuser
  directrtpsetup dtmfmode fromuser fromdomain fullcontact fullname host incominglimiti outgoinglimit insecureipaddr language mailbox md5secret musicclass musiconhold
  subscribemwi name nat outboundproxy permit deny mask
  pickupgroup port progressinband promiscredir qualify regexten regseconds restrictcid rtpkeepalive rtptimeout rtpholdtimeout secret sendrpid setvar subscribecontext trunkname
  trustrpid type useclientcode usereqphone username vmexten).each do |property|
    define_method "#{property}" do
      debug "[getter for #{property}]"
      @property_hash[property.to_sym]
    end

    define_method "#{property}=" do |value|
      debug "[setter for #{property}]"
      @property_hash[property.to_sym] = value

    end
  end


end


# We should maybe look into using ruby-net-ldap sometime as a replacement for ruby-ldap.
# Nic - 22 Aug 2012

require 'net/ldap' #ruby/ldap gem
require 'highline/import' #prompt gem
require 'csv' #csv parsing

if not ARGV.length == 1
  puts "usage: #{File.basename(__FILE__)} student-list.csv"
  exit
end

File.open(ARGV[0], 'r') { |f| @user_list_file = f.read }
@user_data = CSV.new(@user_list_file)

#puts "File:"
#p @user_list_file
#@user_data = @user_list_file.scan(/^,(\d+),"(['\w]+),\s*(\w+ ?[^"]*)".*,(\w+)@.*$/)
#@user_data = @user_list_file.scan(/(\d+),"(['\w]+),\s*(\w+ ?[^"]*)".*,(\w+)@.*$/)
#regex is *not* self-documenting ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# ISSUE TODO: this regex skips users who have whitespace in their name


@conn = Net::LDAP.new 
@conn.host = 'server01.morris.umn.edu'
@conn.port = 389 #LDAP::LDAP_PORT  
# @conn.encryption(:simple_tls)
@sslport = 636 #LDAP::LDAPS_PORT #when applicable
#@conn = LDAP::Conn.new(host=@host, port=@port)

@uidNumber = 1200

def gen_users_and_password()
 # puts("here we go!")
  @user_data.each do |id, last_name, first_name, x500|
    #puts "id #{id}\n last_name #{last_name}\n first_name #{first_name}\n x500 #{x500}"
    if not already_exists?(x500)
      puts("Adding \"" + x500 + "\" to ldap")
      create_ldap_entry(id,last_name, first_name, x500.downcase)
      create_home_dir(x500.downcase)   
      print "\n"
    end
  end
  puts("Done!")
end


def getUniqueUidNumber()
  cn = nil
  puts "Trying uidNumber = #{@uidNumber}"
   entries = @conn.search(:base => 'dc=dungeon,dc=morris,dc=umn,dc=edu', :filter => Net::LDAP::Filter.eq('uidNumber', @uidNumber.to_s()))
   if entries.size > 0
	cn = entries[0][:cn]
   end

   # @conn.search('dc=dungeon, dc=morris, dc=umn, dc=edu', LDAP::LDAP_SCOPE_SUBTREE, "(&(objectclass=person)(uidNumber=#{@uidNumber}))", ['cn']) { |entry|
   #   cn = entry.vals('cn')
   # }
  until cn.nil?
    @uidNumber += 1
   # puts "Trying uidNumber = #{@uidNumber}"
    cn = nil
    begin
    entries = @conn.search(:base => 'dc=dungeon,dc=morris,dc=umn,dc=edu', :filter => Net::LDAP::Filter.eq('uidNumber', @uidNumber.to_s()))
     if entries.size > 0
        cn = entries[0][:cn]
     end
  
    #adadfaf
    rescue 
      puts("LDAP error searching for uidNumber #{@uidNumber}")
      puts("Error: " + @conn.get_operation_result.message)
      exit
    end
  end
  puts "uidNumber #{@uidNumber} should be unique"
end

def create_ldap_entry(id, last_name, first_names, x500)
  getUniqueUidNumber()
  cn = first_names+ ' ' + last_name

 dn = "cn=#{cn}, ou=People, dc=dungeon, dc=morris, dc=umn, dc=edu"
  user_entry = {
       :objectclass => ['inetOrgPerson','posixAccount','top'],
       :givenName => [first_names],
       :sn => [last_name],
       :cn => [cn],
       :uid => [x500],
       :userPassword => ["{crypt}" + crypt_password(gen_pass(id, x500))],
       :gidNumber => ["1000"],
       :homeDirectory => ["/home/#{x500}"],
       :loginShell => ["/bin/bash"],
       :uidNumber => ["#{@uidNumber}"]
}

=begin  
user_entry = [
  LDAP.mod(LDAP::LDAP_MOD_ADD,'objectclass',['inetOrgPerson','posixAccount','top']),
  LDAP.mod(LDAP::LDAP_MOD_ADD,'givenName',[first_names]),
  LDAP.mod(LDAP::LDAP_MOD_ADD,'sn',[last_name]),
  LDAP.mod(LDAP::LDAP_MOD_ADD,'cn',[cn]),
  LDAP.mod(LDAP::LDAP_MOD_ADD,'uid',[x500]),
  LDAP.mod(LDAP::LDAP_MOD_ADD, 'userPassword', ["{crypt}" + crypt_password(gen_pass(id, x500))]),
  LDAP.mod(LDAP::LDAP_MOD_ADD, 'gidNumber', ["1000"]),
  LDAP.mod(LDAP::LDAP_MOD_ADD, 'homeDirectory', ["/home/#{x500}"]),
  LDAP.mod(LDAP::LDAP_MOD_ADD, 'loginShell', ["/bin/bash"]),
  LDAP.mod(LDAP::LDAP_MOD_ADD, 'uidNumber', ["#{@uidNumber}"]) 
  ]
=end
  #p(user_entry)
  begin
   # puts("starting to add to ldap")
    @conn.add :dn => dn, :attributes => user_entry 
    puts @conn.get_operation_result.message
   #puts("it worked!")
  rescue
    puts("crap!")
    puts("LDAP error on user #{x500}!")
    puts("Error: " + @conn.get_operation_result.message)
  end
end

def gen_pass(id, x500)
  pass = id[-3..-1] + x500
  return pass 
end

def get_salt()
    len = 8
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
end

def crypt_password(pass)
  return pass.crypt("$1$" + get_salt())
end


def already_exists?(uid)
  cn = nil
  entries = @conn.search(:base => 'dc=dungeon,dc=morris,dc=umn,dc=edu', :filter => Net::LDAP::Filter.eq('uid', uid))
     if entries.size > 0
        cn = entries[0]
     end

  if not cn.nil?
    puts("User ID: \"#{uid}\" already exists in LDAP, skipping creation of /raid/home/#{uid}")
    return true
  elsif File.exists?("/raid/home/#{uid}")
    puts("Error: directory /raid/home/#{uid} already exists, \"#{uid}\" will not be added to LDAP")
    return true
  end 
  #puts("User is new!")
  return false
end


#def create_user_account(x500)
#  `mkdir /raid/home/#{x500}`
#  `tar -xf skel.tar -C /raid/home/#{x500}`
#  `chown -R #{x500}:users /raid/home/#{x500}`
#end

def create_home_dir(x500)
  #puts "entered create_user_account"
#  if not File.exists? "/raid/home/#{x500}" # we do the safety check elsewhere
    puts("creating /raid/home/#{x500}")
    #`mkdir /raid/home/#{x500}`
    #`tar -xf skel.tar -C /raid/home/#{x500}`
    `cp -r skel /raid/home/#{x500}`
    `find /raid/home/#{x500} -type d -exec setfacl --set "user::rwx,group::--x,other::--x,default:user::rwx,default:group::--x,default:other::--x" {} \\;`
    `find /raid/home/#{x500} -type f -exec setfacl --modify "group::---,other::---" {} \\;`
    `setfacl -R --set "user::rwx,group::r-x,other::r-x,default:user::rwx,default:group::r-x,default:other::r-x" /raid/home/#{x500}/Public`
    #`chmod 0701 /raid/home/#{x500}`
    `chown -R #{x500}:users /raid/home/#{x500}`
#  else
#   puts("/raid/home/#{x500} already exists")
#  end
end


def get_password(prompt="Enter Password")
  ask(prompt) {|q| q.echo = false}
end

###################### actions

############ prompt ldap password


def getPassword
  admin_pass = get_password(prompt="Ldap Password: ")
  if admin_pass == ''
    puts "You must enter the Ldap password."
    exit
  end
  return admin_pass
end

#########
######### End Method declarations, begin run
#########

############ check ldap password

begin
    puts("Trying to bind")
    @conn.auth 'cn=admin, dc=dungeon, dc=morris, dc=umn, dc=edu', getPassword
    if(@conn.bind)
      puts("we've bound")
    else
      puts("An error occured!: " + @conn.get_operation_result.message)
      exit
    end
 #   if @conn.err == 49
#		puts "Invalid LDAP password."
 #   	exit
  #  end
   # @conn.perror("Error binding to ldap")
end

############ generate user and password

gen_users_and_password()



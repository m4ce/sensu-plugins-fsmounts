#!/usr/bin/env ruby
#
# check-fsmounts.rb
#
# Author: Matteo Cerutti <matteo.cerutti@hotmail.co.uk>
#

require 'sensu-plugin/check/cli'
require 'json'
require 'socket'
require 'sys/filesystem'
require 'fstab'

class CheckFsMounts < Sensu::Plugin::Check::CLI
  option :fstype,
         :description => "Comma separated list of file system type(s) (default: all)",
         :long => "--fstype <TYPE>",
         :proc => proc { |a| a.split(',') },
         :default => []

  option :ignore_fstype,
         :description => "Comma separated list of file system type(s) to ignore",
         :long => "--ignore-fstype <TYPE>",
         :proc => proc { |a| a.split(',') },
         :default => []

  option :mount,
         :description => "Comma separated list of mount point(s) (default: all)",
         :long => "--mount <MOUNTPOINT>",
         :proc => proc { |a| a.split(',') },
         :default => []

  option :mount_regex,
         :description => "Comma separated list of mount point(s) (regex)",
         :long => "--mount-regex <MOUNTPOINT>",
         :proc => proc { |a| a.split(',') },
         :default => []

  option :ignore_mount,
         :description => "Comma separated list of mount point(s) to ignore",
         :long => "--ignore-mount <MOUNTPOINT>",
         :proc => proc { |a| a.split(',') },
         :default => []

  option :ignore_mount_regex,
         :description => "Comma separated list of mount point(s) to ignore (regex)",
         :long => "--ignore-mount-regex <MOUNTPOINT>",
         :proc => proc { |a| a.split(',') },
         :default => []

  option :handlers,
         :description => "Comma separated list of handlers",
         :long => "--handlers <HANDLER>",
         :proc => proc { |s| s.split(',') },
         :default => []

  option :warn,
         :description => "Warn instead of throwing a critical failure",
         :short => "-w",
         :long => "--warn",
         :boolean => true,
         :default => false

  option :dryrun,
         :description => "Do not send events to sensu client socket",
         :long => "--dryrun",
         :boolean => true,
         :default => false

  def initialize()
    super

    # retrieve all entries in the system fstab
    @fstab_entries = get_fstab_entries()

    # discover currently mounted filesystems
    @mounted_filesystems = get_mounted_filesystems()
  end

  def get_fstab_entries()
    entries = {}

    fstab = Fstab.new("/etc/fstab")
    fstab.entries.each do |device, entry|
      if config[:ignore_fstype].size > 0
        next if config[:ignore_fstype].include?(entry[:type])
      end

      if config[:fstype].size > 0
        next unless config[:fstype].include?(entry[:type])
      end

      if config[:ignore_mount].size > 0
        next if config[:ignore_mount].include?(entry[:mount_point])
      end

      if config[:ignore_mount_regex].size > 0
        b = false
        config[:ignore_mount_regex].each do |mnt|
          if entry[:mount_point] =~ Regexp.new(mnt)
            b = true
            break
          end
        end
        next if b
      end

      if config[:mount].size > 0
        next unless config[:mount].include?(entry[:mount_type])
      end

      if config[:mount_regex].size > 0
        b = true
        config[:mount_regex].each do |mnt|
          if entry[:mount_point] =~ Regexp.new(mnt)
            b = false
            break
          end
        end
        next if b
      end

      entries[device] = {
        :mount_point => entry[:mount_point]
      }
    end

    entries
  end

  def get_mounted_filesystems()
    mounts = {}

    Sys::Filesystem.mounts.each do |fs|
      # always ignore the following mount types
      #next if ["rootfs", "proc", "sysfs", "devtmpfs", "devpts", "securityfs", "autofs", "pstore"].include?(fs.mount_type)

      if config[:ignore_fstype].size > 0
        next if config[:ignore_fstype].include?(fs.mount_type)
      end

      if config[:fstype].size > 0
        next unless config[:fstype].include?(fs.mount_type)
      end

      if config[:ignore_mount].size > 0
        next if config[:ignore_mount].include?(fs.mount_type)
      end

      if config[:ignore_mount_regex].size > 0
        b = false
        config[:ignore_mount_regex].each do |mnt|
          if fs.mount_point =~ Regexp.new(mnt)
            b = true
            break
          end
        end
        next if b
      end

      if config[:mount].size > 0
        next unless config[:mount].include?(fs.mount_type)
      end

      if config[:mount_regex].size > 0
        b = true
        config[:mount_regex].each do |mnt|
          if fs.mount_point =~ Regexp.new(mnt)
            b = false
            break
          end
        end
        next if b
      end

      mounts[fs.name] = {
        :mount_point => fs.mount_point
      }
    end

    mounts
  end

  def send_client_socket(data)
    if config[:dryrun]
      puts data.inspect
    else
      sock = UDPSocket.new
      sock.send(data + "\n", 0, "127.0.0.1", 3030)
    end
  end

  def send_ok(check_name, msg)
    event = {"name" => check_name, "status" => 0, "output" => "#{self.class.name} OK: #{msg}", "handlers" => config[:handlers]}
    send_client_socket(event.to_json)
  end

  def send_warning(check_name, msg)
    event = {"name" => check_name, "status" => 1, "output" => "#{self.class.name} WARNING: #{msg}", "handlers" => config[:handlers]}
    send_client_socket(event.to_json)
  end

  def send_critical(check_name, msg)
    event = {"name" => check_name, "status" => 2, "output" => "#{self.class.name} CRITICAL: #{msg}", "handlers" => config[:handlers]}
    send_client_socket(event.to_json)
  end

  def send_unknown(check_name, msg)
    event = {"name" => check_name, "status" => 3, "output" => "#{self.class.name} UNKNOWN: #{msg}", "handlers" => config[:handlers]}
    send_client_socket(event.to_json)
  end

  def run
    problems = 0

    # check if currently mounted filesystems have an entry in fstab
    @mounted_filesystems.each do |device, mount|
      check_name = "fsmounts-#{mount[:mount_point].gsub('/', '_')}"

      if @fstab_entries.has_key?(device)
        if @fstab_entries[device][:mount_point] == mount[:mount_point]
          send_ok(check_name, "Device #{device} mounted at #{mount[:mount_point]} found in /etc/fstab")
        else
          msg = "Device #{device} found in /etc/fstab but mountpoints do not match!"

          if config[:warn]
            send_warning(check_name, msg)
          else
            send_critical(check_name, msg)
          end

          problems += 1
        end
      else
        msg = "Device #{device} mounted at #{mount[:mount_point]} not found in /etc/fstab"

        if config[:warn]
          send_warning(check_name, msg)
        else
          send_critical(check_name, msg)
        end

        problems += 1
      end
    end

    # now check if fstab entries are mounted
    @fstab_entries.each do |device, entry|
      check_name = "fsmounts-#{entry[:mount_point].gsub('/', '_')}"

      unless @mounted_filesystems.has_key?(device)
        msg = "Fstab entry with device #{device} and mountpoint #{entry[:mount_point]} is not mounted"

        if config[:warn]
          send_warning(check_name, msg)
        else
          send_critical(check_name, msg)
        end

        problems += 1
      end
    end

    if problems > 0
      message("Found #{problems} problems")
      warning if config[:warn]
      critical
    else
      ok("All mountpoints are OK")
    end
  end
end

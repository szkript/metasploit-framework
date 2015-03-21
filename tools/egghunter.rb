msfbase = __FILE__
while File.symlink?(msfbase)
  msfbase = File.expand_path(File.readlink(msfbase), File.dirname(msfbase))
end
$:.unshift(File.expand_path(File.join(File.dirname(msfbase), '..', 'lib')))
require 'msfenv'
require 'rex'
require 'msf/core'
require 'msf/base'
require 'optparse'

module Egghunter
  class OptsConsole
    def self.parse(args)
      options = {}
      parser = OptionParser.new do |opt|
        opt.banner = "Usage: #{__FILE__} [options]\nExample: #{__FILE__} -f python -e W00T"
        opt.separator ''
        opt.separator 'Specific options:'

        options[:badchars] = ''
        options[:platform] = 'windows'
        options[:arch]     = ARCH_X86 # 'x86'

        opt.on('-f', '--format <String>', "See --list-formats for a list of supported output formats") do |v|
          options[:format] = v
        end

        opt.on('-b', '--badchars <String>', "(Optional) Bad characters to avoid for the egg") do |v|
          options[:badchars] = v
        end

        opt.on('-e', '--egg <String>', "The egg (Please give 4 bytes)") do |v|
          options[:eggtag] = v
        end

        opt.on('-p', '--platform <String>', "(Optional) Platform") do |v|
          options[:platform] = v
        end

        opt.on('--startreg <String>', "(Optional) The starting register") do |v|
          # Do not change this key. This should matching the one in Rex::Exploitation::Egghunter
          options[:startreg] = v
        end

        opt.on('--forward', "(Optional) To search forward") do |v|
          # Do not change this key. This should matching the one in Rex::Exploitation::Egghunter
          options[:startreg] = true
        end

        opt.on('--depreg <String>', "(Optional) The DEP register") do |v|
          # Do not change this key. This should matching the one in Rex::Exploitation::Egghunter
          options[:depreg] = v
        end

        opt.on('--depdest <String>', "(Optional) The DEP destination") do |v|
          # Do not change this key. This should matching the one in Rex::Exploitation::Egghunter
          options[:depdest] = v
        end

        opt.on('--depsize <Fixnum>', "(Optional) The DEP size") do |v|
          # Do not change this key. This should matching the one in Rex::Exploitation::Egghunter
          options[:depsize] = v
        end

        opt.on('--depmethod <String>', "(Optional) The DEP method to use (virtualprotect/virtualalloc/copy/copy_size)") do |v|
          # Do not change this key. This should matching the one in Rex::Exploitation::Egghunter
          options[:depmethod] = v
        end

        opt.on('-a', '--arch <String>', "(Optional) Architecture") do |v|
          # Although this is an option, this is currently useless because we don't have x64 egghunters
          options[:arch] = v
        end

        opt.on('--list-formats', "List all supported output formats") do
          options[:list_formats] = true
        end

        opt.on_tail('-h', '--help', 'Show this message') do
          $stdout.puts opt
          exit
        end
      end

      parser.parse!(args)

      if options.empty?
        raise OptionParser::MissingArgument, 'No options set, try -h for usage'
      elsif options[:format].blank? && !options[:list_formats]
        raise OptionParser::MissingArgument, '-f is required'
      elsif options[:eggtag].blank? && !options[:list_formats]
        raise OptionParser::MissingArgument, '-e is required'
      elsif options[:format] && !::Msf::Simple::Buffer.transform_formats.include?(options[:format])
        raise OptionParser::InvalidOption, "#{options[:format]} is not a valid format"
      elsif options[:depsize] && options[:depsize] !~ /^\d+$/
        raise OptionParser::InvalidOption, "--depsize must be a Fixnum"
      end

      options
    end
  end

  class Driver
    def initialize
      begin
        @opts = OptsConsole.parse(ARGV)
      rescue OptionParser::ParseError => e
        $stderr.puts "[x] #{e.message}"
        exit
      end
    end

    def run
      # list_formats should check first
      if @opts[:list_formats]
        list_formats
        return
      end

      egghunter = Rex::Exploitation::Egghunter.new(@opts[:platform], @opts[:arch])
      raw_code = egghunter.hunter_stub('', @opts[:badchars], @opts)
      output_stream = $stdout
      output_stream.binmode
      output_stream.write ::Msf::Simple::Buffer.transform(raw_code, @opts[:format])
    end

    private

    def list_formats
      $stderr.puts "[*] Supported output formats:"
      $stderr.puts ::Msf::Simple::Buffer.transform_formats.join(", ")
    end

  end
end


if __FILE__ == $PROGRAM_NAME
  driver = Egghunter::Driver.new
  begin
    driver.run
  rescue ::Exception => e
    elog("#{e.class}: #{e.message}\n#{e.backtrace * "\n"}")
    $stderr.puts "[x] #{e.class}: #{e.message}"
    $stderr.puts "[*] If necessary, please refer to framework.log for more details."
  end
end
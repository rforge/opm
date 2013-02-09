#!/usr/bin/env ruby


################################################################################
#
# repair_s4_docu.rb -- Ruby script to repair the missing entries in the Rd
# documentation of S4 methods generated by Roxygen2. Part of the pkgutils 
# package. It can be directly called using R functions from that package.
#
# Names of R files must be provided at the command line. The names of the Rd
# files are generated from the names of the S4 methods found in these R files.
# For this to work, the names of the R files must contain the name of the 
# package directory, e.g. "./mypackage/R/data.R".
#
# Successful usage of this script depends on certain conventions when writing
# S4 method definitions. It requires particular care when working with special
# method names, such as infix operators, bracket operators, and replacement
# functions.
#
# (C) 2012 by Markus Goeker (markus [DOT] goeker [AT] dsmz [DOT] de)
#
# This program is distributed under the terms of the Gnu Public License V2.
# For further information, see http://www.gnu.org/licenses/gpl.html
#
################################################################################


require 'optparse'


################################################################################


# === Structured data describing an S4 method for R or S
#
class S4_Method


  class Format_Problem < RuntimeError; end


  RD_FILE_MAP = Hash.new {|h, k| h[k] = k}


  # The named subexpressions are only available in Ruby 1.9.0 or higher.
  #
  PATTERN = /
    ^\s*
    set(?:Replace)?Method\s*
    \(\s*(?:"(?<name>[^"]+)"|(?<name>func_))\s*,\s*(signature\s*=\s*)?
    (?<s4_class>\S+(?:\s+\S+)*)\s*,\s*
    function\s*(?<args>\(.*)
  /xm


  @@placeholders = []
  @@placeholder_idx = -1
  @@func_index = -1
  @@placeholder_region = false

  
  class << self


    # Use line _str_ for registering placeholders (which are used to
    # automatically generate method descriptions) and mappings of rd files.
    #
    def register_placeholders str
      if @@placeholder_region
        case str
        when /^\s*#\+\s*$/
          raise Format_Problem, str.to_s
        when /^\s*#-\s*$/
          @@placeholder_region = false
        when /^\s*#=/
          raise Format_Problem, str.to_s
        else
          @@placeholders[@@placeholder_idx] << str.strip.sub(/\s*,$/,
            "").sub(/^"([^"]+)"$/, "\\1")
        end
      else
        case str
        when /^\s*#=/
          register_rd_file_mapping str.sub(/^[^=]+=\s*/, "")
        when /^\s*#\+\s*$/
          @@placeholder_region = true
          @@placeholders[@@placeholder_idx += 1] = []
        when /^\s*#-\s*$/
          raise Format_Problem, str.to_s
        else
          nil
        end
      end
      nil
    end
    
    
    def register_rd_file_mapping str #:nodoc:
      fields = str.split
      RD_FILE_MAP[fields.fetch 0] = fields.fetch 1 do
        raise Format_Problem, str.to_s
      end
      warn fields.join(" => ")
    end


    def match str # :nodoc:
      PATTERN.match str
    end


    private :match, :register_rd_file_mapping


    # Check whether line _str_ represents an S4 method for S or R.
    #
    def is? str
      !!match(str)
    end


    # Main constructor function for creating an object from the class. _str_
    # should be a line from file _filename_ and hold the S4 method's
    # description.
    #
    def construct str, filename
      found = match str.to_s
      raise ArgumentError, str.to_s unless found
      if found[:name] == 'func_'
        placeholders = @@placeholders[@@func_index += 1]
        if placeholders.nil? or placeholders.empty?
          raise ArgumentError, "expected placeholders for line: #{str}"
        end
        placeholders.collect do |placeholder|
          new placeholder.dup, found[:s4_class], found[:args], filename
        end
      else
        new found[:name], found[:s4_class], found[:args], filename
      end
    end


  end


  # Create S4 description object with _name_ as the name of the method,
  # _s4_class_ as the method's class, _args_ as its arguments, and _filename_
  # as the name of the file in which the method definition was found.
  #
  def initialize name, s4_class, args, filename
    if name == 'func_'
      raise ArgumentError, 
        "name cannot be 'func_' (#{s4_class}, #{args}, #{filename})" 
    end
    @name, @s4_class = name.sub(/^`([^`]+)`$/, "\\1"), s4_class
    @s4_class = @s4_class.scan(/[\w.]+/).select {|x| x != 'c'}.join(",")
    @args = args.sub(/\{\s*$/m, "").sub(/\s*\w+@.*/m, "")
    @filename, @rdfile = filename.to_s, nil
  end


  attr_reader :name, :s4_class, :args, :filename


  # Create a simple description of the object, mainly for use in error 
  # messages.
  #
  def to_s
    "#{@filename}: #{@name}#{@args}\n"
  end


private


  def special_method? # :nodoc:
    !!(@name =~ /[^\w,.]/)
  end


  def s4_method_tag # :nodoc:
    template = "  \\S4method{%s}{%s}%s"
    if @name =~ /<-$/
      template.% [@name.sub(/<-$/, ""), @s4_class,
        @args.sub(/,\s*value/, "").rstrip + " <- value"]
    else
      template.% [@name.gsub(/%/, "\\%"), @s4_class, @args]
    end
  end


  def cleaned_name # :nodoc:
    RD_FILE_MAP[case @name
    when '['
      'bracket'
    when '[['
      'double.bracket'
    when /<-$/
      @name.sub(/<-$/, ".set")
    when '+'
      'plus'
    when '-'
      'minus'
    when /^(%[a-z]+%|"%[a-z]+%")$/
      "infix.#{@name.gsub(/\W/, "")}"
    when /^(%[A-Z]+%|"%[A-Z]+%")$/
      "infix.large#{@name.gsub(/\W/, "").downcase}"
    else
      @name
    end]
  end


  def cleaned_s4_class # :nodoc:
    @s4_class.scan(/\w+/).first
  end


  def cleaned_s4_classes # :nodoc:
    @s4_class.scan(/\w+/).join('-plus')
  end


  def man_dir # :nodoc:
    File.join File.dirname(File.dirname @filename), "man"
  end


  def obvious_rd_file # :nodoc:
    File.join man_dir, "#{cleaned_name}.Rd"
  end


public


  # Create array of names Rd files one of which is expected.
  #
  def possible_rd_files # :nodoc:
    [obvious_rd_file]
  end


  # Check potential locations of the S4 method's Rd file and return the first
  # one that exists, nil if there is none.
  #
  def existing_rd_file
    @rdfile ||= possible_rd_files.select {|file| File.exist? file}.first
  end


  # Create Rd doctype tag with content.
  #
  def doctype
    "\\docType{methods}"
  end


  # Create Rd aliases tags and return them, joined by newlines.
  #
  def aliases generic
    result, is_special = [], special_method?
    name = is_special ? cleaned_name : @name
    if generic and (file = existing_rd_file) and
        not file =~ /#{cleaned_s4_class}/
      result << "\\alias{#{name}-methods}"
    end
    result << "\\alias{#{name},#{@s4_class}-method}"
    if is_special
      result << "\\alias{#{@name.gsub(/%/, "\\%")},#{@s4_class}-method}"
    end
    result.join "\n"
  end


  # Create an element of the Rd usage entry, depending on _what_, which is
  # either :start, :end or :middle.
  #
  def usage what
    case what
    when :start
      "\\usage{"
    when :end
      "}"
    when :middle
      s4_method_tag
    else
      raise ArgumentError, what.to_s
    end
  end


end


################################################################################


class String


  # Use self as the name of a file with R code from which to collect S4 methods
  # and their definitions. Return array of S4_method objects.
  #
  def all_s4_methods
    result, current, in_s4_method = [], "", false
    File.foreach self do |line|
      if S4_Method.is? line
        result << S4_Method.construct(current, self) unless current.empty?
        current.clear
        in_s4_method = true
      end
      if in_s4_method
        current << line
        in_s4_method = false if line =~ /\{\s*$/
      else
        S4_Method.register_placeholders line
      end
    end
    result << S4_Method.construct(current, self) unless current.empty?
    result.flatten
  end


end


################################################################################


class Array


  # Use self as array of file names from which to collect S4_method objects.
  # Return hash table with Rd file as key and arrays of S4_method objects as
  # values.
  #
  def collect_s4_methods
    s4_methods = collect(&:all_s4_methods).flatten
    result = Hash.new {|h, k| h[k] = []}
    s4_methods.each do |s4_method|
      if (rdfile = s4_method.existing_rd_file)
        result[rdfile] << s4_method
      else
        raise "Rd files for method #{s4_method.name} " +
          "(#{s4_method.possible_rd_files.join(", ")}) do not exist!"
      end
    end
    result
  end


end


################################################################################


class Hash


  # Use self as hash with keys indicating names of Rd files, and as values
  # arrays of S4_method objects whose description shall be written to such a
  # file.
  #
  def write_s4_methods args
    each_pair do |rdfile, s4_methods|
      warn "Adding to #{rdfile}" if args[:verbose]
      File.open(rdfile, "a") do |file|
        file.puts s4_methods.first.doctype
        generic = true
        s4_methods.each do |s4_method|
          file.puts s4_method.aliases(generic)
          generic = false
        end
        file.puts s4_methods.first.usage(:start)
        s4_methods.each do |s4_method|
          file.puts s4_method.usage(:middle)
          file.puts ''
        end
        file.puts s4_methods.first.usage(:end)
      end
    end
  end


end


################################################################################


help_msg, verbose = false, true


opts = OptionParser.new
opts.on('-h', '--help', 'Print help message and exit') {|v| help_msg = true}
opts.on('-q', '--quiet', 'Run quietly') {|v| verbose = false}


filenames = opts.parse ARGV

if help_msg or filenames.empty?
  warn opts.to_s
  exit 1
end


################################################################################


filenames.collect_s4_methods.write_s4_methods(verbose: verbose)


################################################################################


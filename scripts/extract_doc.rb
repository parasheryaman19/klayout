#!/usr/bin/ruby

$script_call = $0 + " " + ARGV.join(" ")

$key="%DRC%"
$infile="src/drc/drc/built-in-macros/drc.lym" 
$loc = "about/drc_ref"
$outfiles="src/lay/lay/doc"
$title="DRC Reference"

def create_ref(s)
  if s =~ /(.*)#(.*)/
    "<a href=\"/" + $loc + "_" + $1.downcase + ".xml#" + $2 + "\">#{s}</a>"
  else
    "<a href=\"#" + s + "\">#{s}</a>"
  end
end

def create_class_doc_ref(s)
  "<class_doc href=\"" + s + "\">#{s}</class_doc>"
end

def escape(s)
  s.gsub("&", "&amp;").
    gsub("<", "&lt;").
    gsub(">", "&gt;").
    gsub(/\\([\w#]+)/) { create_ref($1) }.
    gsub(/RBA::([\w#]+)/) { create_class_doc_ref($1) }
end

def unescape(s)
  s.gsub("&amp;", "&").gsub("&lt;", "<").gsub("&gt;", ">")
end

class DocItem

  attr_accessor :brief
  attr_accessor :synopsis
  attr_accessor :name
  attr_accessor :doc

  def initialize(block)

    @paragraphs = []
    para = nil
    self.synopsis = []
    in_code = false

    block.each do |b|
      if in_code
        if b =~ /@\/code/
          in_code = false
        end
        para.push(b)
      elsif b =~ /^@brief\s+(.*?)\s*$/
        self.brief = $1
      elsif b =~ /^@name\s+(.*?)\s*$/
        self.name = $1
      elsif b =~ /^@synopsis\s+(.*?)\s*$/
        self.synopsis.push($1)
      elsif b =~ /^@scope/
        # ignore scope commands
      elsif b =~ /^\s*$/
        para && @paragraphs.push(para)
        para = nil
      else
        para ||= []
        para.push(b)
        if b =~ /@code/ 
          in_code = true
        end
      end
    end

    para && @paragraphs.push(para)

  end

  def produce_doc

    if @paragraphs.empty?
      return ""
    end

    doc = "<p>\n"

    @paragraphs.each_with_index do |p, i|
      
      i > 0 && doc += "</p><p>\n"

      p.each do |pp|
        doc += escape(pp).
              gsub(/\\@/, "&at;").
              gsub(/\s*@code\s*/, "<pre>").
              gsub(/\s*@\/code\s*/, "</pre>").
              gsub(/@img\((.*)\)\s*/) { "<img src=\"" + $1 + "\"/>" }.
              gsub(/@\/img\s*/, "</img>").
              gsub(/@(\w+)\s*/) { "<" + $1 + ">" }.
              gsub(/@\/(\w+)\s*/) { "</" + $1 + ">" }.
              gsub(/&at;/, "@")
        doc += "\n"
      end

    end

    doc += "</p>\n"

  end

end

class Scope < DocItem

  def initialize(block)
    super(block)
    @items = {}
  end

  def add_doc_item(block)
    item = DocItem::new(block)
    @items[item.name] = item
  end

  alias :super_produce_doc :produce_doc

  def produce_doc

      doc = <<HEAD
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE language SYSTEM "klayout_doc.dtd">

<!-- generated by #{$script_call} -->
<!-- DO NOT EDIT! -->

HEAD

    doc += "<doc>\n"
    doc += "<title>" + escape(self.brief) + "</title>\n"
    doc += "<keyword name=\"" + escape(self.name) + "\"/>\n"

    doc += super_produce_doc

    doc += "<h2-index/>\n"

    @items.keys.sort.each do |item_key|

      item = @items[item_key]

      item.name || raise("Missing @name for item #{item_key}")
      item.brief || raise("Missing @brief for item #{item_key}")

      doc += "<h2>\"" + escape(item.name) + "\" - " + escape(item.brief) + "</h2>\n"
      doc += "<keyword name=\"" + escape(item.name) + "\"/>\n"
      doc += "<a name=\"" + escape(item.name) + "\"/>"
      if ! item.synopsis.empty?
        doc += "<p>Usage:</p>\n"
        doc += "<ul>\n"
        item.synopsis.each do |s|
          doc += "<li><tt>" + escape(s) + "</tt></li>\n"
        end
        doc += "</ul>\n"
      end

      doc += item.produce_doc

    end

    doc += "</doc>\n"

    doc

  end

end

class Collector

  def add_block(block)

    if block.find { |l| l =~ /^@scope/ }

      # is a scope block
      @scopes ||= {}
      @current_scope = Scope::new(block)
      @scopes[@current_scope.name] = @current_scope

    else
      @current_scope && @current_scope.add_doc_item(block)
    end

  end

  def produce_doc

    @scopes.keys.sort.each do |k|
      suffix = k.downcase
      outfile = $outfiles + "/" + $loc + "_" + suffix + ".xml"
      File.open(outfile, "w") do |file|
        file.write(@scopes[k].produce_doc)
        puts "---> #{outfile} written."
      end
    end

  end

  def produce_index

    outfile = $outfiles + "/" + $loc + ".xml"
    File.open(outfile, "w") do |file|

      doc = <<HEAD
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE language SYSTEM "klayout_doc.dtd">

<!-- generated by #{$script_call} -->
<!-- DO NOT EDIT! -->

HEAD

      doc += "<doc>\n"

      doc += "<title>#{escape($title)}</title>\n"
      doc += "<keyword name=\"#{escape($title)}\"/>\n"

      doc += "<topics>\n"

      @scopes.keys.sort.each do |k|
        suffix = k.downcase
        doc += "<topic href=\"/#{$loc}_#{suffix}.xml\"/>\n"
      end

      doc += "</topics>\n"
      doc += "</doc>\n"

      file.write(doc)

    end

    puts "---> Index file #{outfile} written."

  end

end

collector = Collector::new

File.open($infile, "r") do |file|

  block = nil

  file.each_line do |l|
    l = unescape(l)
    if l =~ /^\s*#\s*#{$key}/
      block = []
    elsif l =~ /^\s*#\s*(.*)\s*$/
      block && block.push($1)
    elsif l =~ /^\s*$/
      block && collector.add_block(block)
      block = nil
    end

  end

end

collector.produce_doc
collector.produce_index


require 'treetop'
require 'abnf'

class Treetop::Runtime::SyntaxNode
  def clean_abnf
    if elements
      elements.map {|el| el.clean_abnf}.join
    else
      text_value
    end
  end
  def ast
    fail "undefined_ast #{inspect}"
  end
  def ast_from_percent(base, first, second)
    c1 = first.to_i(base).chr(Encoding::UTF_8)
    case second[0]
    when nil
      ["cs", c1]
    when "-"
      c2 = second[1..-1].to_i(base).chr(Encoding::UTF_8)
      ["char-range", c1, c2]
    when "."
      el = second.split(".")
      el[0] = first
      ["cs", el.map {|c| c.to_i(base).chr(Encoding::UTF_8)}.join]
    else
      fail "ast_from_percent"
    end
  end
end


class ABNF
  @@parser = ABNFGrammarParser.new

  def self.from_abnf(s)
    ast = @@parser.parse s
    if !ast
      reason = @@parser.failure_reason
      @@parser.failure_reason =~ /^(Expected .+) after/m
      reason << "#{$1.gsub("\n", '<<<NEWLINE>>>')}:" if $1
      if line = s.lines.to_a[@@parser.failure_line - 1]
        reason << line
        reason << "#{'~' * (@@parser.failure_column - 1)}^"
      end
      fail reason
    end
    ABNF.new(ast)
  end

  attr_accessor :ast, :rules
  def initialize(ast_)
    @ast = ast_
    tree = ast.ast
    @rules = {}
    tree.each do |x|
      op, name, val, rest = x
      fail rest if rest
      fail op unless op == "="  # XXX
      if @rules[name]
        fail "duplicate for name #{name}"
      end
      @rules[name] = val
    end
  end

  def generate
    generate1(rules.first.first)
  end

  def generate1(what)
    case what
    when String
      expansion = rules[what]
      fail "can't find rules #{what}" unless expansion
      generate1(expansion)
    when Array
      op, *args = what
      case op
      when "seq"
        args.map {|arg| generate1(arg)}.join
      when "alt"
        generate1(args.sample)
      when "rep"
        l, h, x, rest = args
        fail rest if rest
        h = l+3 if h == true
        n = rand(h-l+1)+l
        (0...n).map { generate1(x) }.join
      when "ci"
        s, rest = args
        fail rest if rest
        s.chars.map{|x|[x.upcase, x.downcase].sample}.join
      when "cs"
        s, rest = args
        fail rest if rest
        s
      when "char-range"
        l, r = args
        fail rest if rest
        (rand(r.ord-l.ord+1)+l.ord).chr(Encoding::UTF_8)
      when "prose" # ["prose", text]
        fail "prose not implemented #{what.inspect}"
      when "im"
        warn "abnftt-style inline module ignored #{what.inspect}"
        ''
      else
        fail [op, args].inspect
      end
    else
      fail
    end
  end
end

require 'treetop'
require 'abnfgrammar'

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

  def self.reason(parser, s)
    reason = [parser.failure_reason]
    parser.failure_reason =~ /^(Expected .+) after/m
    reason << "#{$1.gsub("\n", '<<<NEWLINE>>>')}:" if $1
    if line = s.lines.to_a[parser.failure_line - 1]
      reason << line
      reason << "#{'~' * (parser.failure_column - 1)}^"
    end
    reason.join("\n")
  end

  def self.from_abnf(s)
    ast = @@parser.parse s
    if !ast
      fail self.reason(@@parser, s)
    end
    ABNF.new(ast)
  end

  attr_accessor :ast, :rules, :tree
  def initialize(ast_)
    @ast = ast_
    @tree = ast.ast
    @rules = {}
    @tree.each do |x|
      op, name, val, rest = x
      fail rest if rest
      @rules[name] =
        if old = @rules[name]
          fail "duplicate rule for name #{name}" if op == "="
          if Array === old && old[0] == "alt"
            old.dup << val
          else
            ["alt", old, val]
          end
        else
          val
        end
    end
    # warn "** rules #{rules.inspect}"
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


  def to_treetop(modname)
    <<~EOS
    # Encoding: UTF-8
    grammar #{modname}
    #{rules.map {|k, v| to_treetop0(k, v)}.join}
    end
  EOS
  end
  def to_treetop0(k, v)
    <<~EOS
    rule #{to_treetop1(k)}
    #{to_treetop1(v)}
    end
  EOS
  end
  FIXUP_NAMES = Hash.new {|h, k| k}
  FIXUP_NAMES.merge!({
                       "rule" => "r__rule",
                       "end" => "r__end",
                     })
  def to_treetop1(ast)
    case ast
    when String
      FIXUP_NAMES[ast].gsub("-", "_")
    when Array
      case ast[0]
      when "alt" # ["alt", *a]
        "(#{ast[1..-1].map {|x| to_treetop1(x)}.join(" / ")})"
      when "seq" # ["seq", *a]
        "(#{ast[1..-1].map {|x| to_treetop1(x)}.join(" ")})"
      when "rep" # ["rep", s, e, a]
        t = to_treetop1(ast[3]) || "@@@"
        case [ast[1], ast[2]]
        when [0, 1]
          t + "?"
        when [0, true]
          t + "*"
        when [1, true]
          t + "+"
        else
          t + " #{ast[1]}..#{ast[2] == true ? '' : ast[2]}"
        end
      when "prose" # ["prose", text]
        fail "prose not implemented #{ast.inspect}"
      when "ci" # ["ci", text]
        s = ast[1]
        if s =~ /\A[^A-Za-z]*\z/
          s.inspect
        else
          s.inspect << "i"        # could do this always, but reduce noise
        end
      when "cs" # ["cs", text]
        ast[1].inspect
      when "char-range" # ["char-range", c1, c2]
        c1 = Regexp.quote(ast[1])
        c2 = Regexp.quote(ast[2])
        "[#{c1}-#{c2}]"           # XXX does that always work
      when "im" # ["im", a, text]
        to_treetop1(ast[1]) + " " + ast[2]
      else
        fail "to_treetop(#{ast.inspect})"
      end
    else
      fail "to_treetop(#{ast.inspect})"
    end
  end

  @@gensym = 0

  attr_accessor :parser
  def validate(s)
    @parser ||= Treetop.load_from_string(to_treetop("ABNF_Mod" << (@@gensym += 1).to_s))
    parser_instance ||= @parser.new
    unless result1 = parser_instance.parse(s)
      fail self.class.reason(parser_instance, s)
    end
  end

end

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

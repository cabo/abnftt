require "abnftt/abnf-visitor.rb"

class ABNF
  def expand_op_into(s, op, out = [op])
    s.each do |el|
      case el
      in [^op, *inner]
        expand_op_into(inner, op, out)
      else
        out << flatten_ops_1(el)
      end
    end
    out
  end
  def flatten_ops_1(prod)
    visit(prod) do |here|
        case here
        in ["seq", *rest]
          [true, expand_op_into(rest, "seq")]
        in ["alt", *rest]
          [true, expand_op_into(rest, "alt")]
        else
          false
        end
    end
  end
  def flatten_ops
    rules.each do |name, prod|
      rules[name] = flatten_ops_1(prod)
    end
  end
end

require_relative "../abnftt.rb"

class ABNF
  def visit_all(prod_array, &block)
    prod_array.map {|prod| visit(prod, &block)}
  end
  def visit(prod, &block)
    done, ret = block.call(prod, &block)
    if done
      return ret
    end

    case prod
    in ["alt", *prods]
      ["alt", *visit_all(prods, &block)]
    in ["tadd", *prods]
      ["tadd", *visit_all(prods, &block)]
    in ["seq", *prods]
      ["seq", *visit_all(prods, &block)]
    in ["rep", s, e, prod]
      ["rep", s, e, visit(prod, &block)]
    else
      prod
    end
  end
end

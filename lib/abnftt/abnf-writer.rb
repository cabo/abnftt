class ABNF

  # TODO: write replacement for .inspect below (backslash, dquote, non-ASCII)
  # return [precedence ((2 if seq needed)), string]

  def write_lhs(k)
      k
  end

  # precedence:
  # 1: / alt -> (type1)
  # 2: »« seq
  # 4: atomic

  def prec_check(inner, targetprec, prec)
    if targetprec >= prec
      "(#{inner})"
    else
      inner
    end
  end

  def write_rhs(v, targetprec = 0)
    prec, ret =
    case v
    in String                   # this should really be ["name", id]
      [4, v]
    in ["name", id]
      [4, id]
    in ["alt" | "tadd", *types]
      [1, types.map{write_rhs(_1, 1)}.join(" / ")]
    in ["seq", *groups]
      case groups.size
      when 0; [4, ""]           # XXX
      else
        [2, "#{groups.map{write_rhs(_1, 2)}.join(" ")}"]
      end
    in ["ci", s]
      [4, s.inspect]
    in ["cs", s]
      if s =~ /\A[^A-Za-z]*\z/
        [4, s.inspect]
      else
        [4, "%s" << s.inspect]  # reduce noise if no alphabetics
      end
    in ["char-range", c1, c2]
      nc1 = "%x" % c1.ord
      nc2 = "%x" % c2.ord
      [4, "%x#{nc1}-#{nc2}"]
    in ["rep", s, e, group]
      occur = case [s, e]
              in [1, 1];    ""
              in [0, true]; "*"
              else
                "#{s}*#{e != true ? e : ""}"
              end
      [4, "#{occur}#{write_rhs(group, 4)}"]
    end
    prec_check(ret, targetprec, prec)
  end

  def write_rule(k, v)
      case v
      in ["tadd", *_rest]
        assign = "=/"
      else
        assign = "="
      end
      "#{write_lhs(k)} #{assign} #{write_rhs(v, 0)}"
  end

  def to_s
    rules.map {|k, v| write_rule(k, v) }.join("\n")
  end

end

class ABNF

  # return [precedence ((2 if seq needed)), string]

  def stringify(s)
    fail "Can't stringify #{s.inspect} yet" unless s =~ /\A[ !#-~]*\z/
    %{"#{s}"}
  end

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
      [4, stringify(s)]
    in ["cs", s]
      if s =~ /\A[^A-Za-z]*\z/
        [4, stringify(s)]
      else
        [4, "%s" << stringify(s)]  # reduce noise if no alphabetics
      end
    in ["char-range", c1, c2]
      nc1 = "%02x" % c1.ord

      nc2 = "%02x" % c2.ord
      nc2add = "-#{nc2}" if nc2 != nc1
      [4, "%x#{nc1}#{nc2add}"]
    in ["rep", s, e, group]
      if s == 0 && e == 1
        [4, "[#{write_rhs(group, 1)}]"]
      else
        occur = case [s, e]
                in [1, 1];    ""
                in [0, true]; "*"
                in [n, ^n]; n.to_s
                else
                  "#{s}*#{e != true ? e : ""}"
                end
        [4, "#{occur}#{write_rhs(group, 4)}"]
      end
    else
      fail [:WRITE_NOMATCH, v].inspect
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

  # primitively break down lines so they fit on a teletype
  def breaker(s, col = 69)
    ret = ""
    s.each_line do |*l|
      while l[-1].size > col
        breakpoint = l[-1][0...col].rindex(' ')
        break unless breakpoint && breakpoint > 4
        l[-1..-1] = [
          l[-1][0...breakpoint],
          "    " << l[-1][breakpoint+1..-1]
        ]
      end
      ret << l.join("\n")
    end
    ret
  end

end

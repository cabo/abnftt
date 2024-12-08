require "abnftt"
require "abnftt/abnf-flattener"
require "abnftt/abnf-util"
require "abnftt/abnf-visitor"

class ABNF

  UNESCAPED_SQSTR_RANGES =
    # [[0xA, 0xA], [0x20, 0x21], [0x23, 0x26], -- but DQUOTE is allowed
    [[0xA, 0xA], [0x20, 0x26],  # "'"
     # [0x28, 0x5b], [0x5d, 0x7e], [0xa0, 0xd7ff], -- but JSON allows 7F-9F
     [0x28, 0x5b], [0x5d, 0xd7ff], # \
     [0xe000, 0x10ffff]].map {|l, r|
    [l.chr(Encoding::UTF_8), r.chr(Encoding::UTF_8)]
  }

  ESCAPED_SQSTR_MAPPINGS = [
    ["\x08", "b"],
    ["\x09", "t"],
    ["\x0A", "n"],
    ["\x0C", "f"],
    ["\x0D", "r"],
    ["\x27", "'"],
    ["\x2F", "/"],
    ["\x5C", "\\"]]

  def squash_edn_levels_1(prod)
    f1 = visit(prod) do |here|
      case here
      in ["char-range", c1, c2]
        lit = UNESCAPED_SQSTR_RANGES.map { |u1, u2|
          overlap(here, u1, u2) }.compact
        esc = ESCAPED_SQSTR_MAPPINGS.map {|cv, ev|
          if cv >= c1 && cv <= c2
            ["seq", ["char-range", "\\", "\\"], ["char-range", ev, ev]]
          end
        }.compact
        old = alt_ranges_legacy(c1.ord, c2.ord)
        new = alt_ranges_modern(c1.ord, c2.ord)
        oldnew = ["seq",
                  ["cs", "\\u"],
                  wrap_flat("alt", [old, new]) ]
        [true, wrap_flat("alt", [*lit, *esc, oldnew].sort)]
      else
        false
      end
    end
    flatten_ops_1(f1)
  end

  def squash_edn_levels
    rules.each do |name, prod|
      rules[name] = squash_edn_levels_1(prod)
    end
  end

end

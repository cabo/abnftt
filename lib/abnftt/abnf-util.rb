require "abnftt/abnf-visitor"
require "abnftt/abnf-flattener"

class ABNF

  def wrap(head, all)
    if all.size == 1
      all.first
    else
      [head, *all]
    end
  end

  def wrap_flat(head, all)
    if all.size == 1
      all.first
    else
      [head, *all.collect_concat {|el|
         case el
         in [^head, *rest]
           rest
         else
           [el]
         end
       }]
    end
  end

  def overlap(cr, l, r)
    if cr[2] >= l && cr[1] <= r
      ["char-range", [cr[1], l].max, [cr[2], r].min]
    end
  end

  # Utilities for creating hexadecimal rules from unsigned integers

  def hexdig_range(l, r)
    alt = []
    if l < 10
      alt << ["char-range",
              (l+0x30).chr(Encoding::UTF_8),
              ([r, 9].min+0x30).chr(Encoding::UTF_8)]
    end
    if r >= 10
      alt << ["char-range", ([l, 10].max+0x41-0xA).chr(Encoding::UTF_8),
              (r+0x41-0xA).chr(Encoding::UTF_8)]
      alt << ["char-range", ([l, 10].max+0x61-0xA).chr(Encoding::UTF_8),
              (r+0x61-0xA).chr(Encoding::UTF_8)]
    end
    wrap("alt", alt)
  end

  # This assumes l and r are preprocessed to have single or full ranges except in one place
  def hex_ranges(l, r, ndig = false)
    ld = l.digits(16)
    rd = r.digits(16)
    ndig ||= rd.size
    seq = []
    (0...ndig).each do |dig|
      seq << hexdig_range(ld[dig] || 0, rd[dig] || 0)
    end
    wrap("seq", seq.reverse)
  end

  # split range into passages that have the property needed for hex_ranges
  def do_range(l, r, step = 4)
    column = 0
    while l <= r
      mask = (1 << step * (column + 1)) - 1
      new_r = l | mask
      if new_r > r # right hand side: come down from mountain
        while column >= 0
          mask >>= step
          new_r = (r + 1) & ~mask
          yield l, new_r - 1, column + 1 if l != new_r
          l = new_r
          column -= 1
        end
        return
      else
        column += 1
        if (l & mask) != 0
          yield l, new_r, column
          l = new_r + 1
        end
      end
    end
  end

  # Support legacy JSON \u/\u\u and \u{...} hex unicode

  def alt_ranges(l, r, step = 4, ndig = false)
    alt = []
    do_range(l.ord, r.ord, step) do |l, r, column|
      alt << hex_ranges(l, r, ndig)
    end
    wrap("alt", alt)
  end

  def alt_ranges_legacy(l, r)
    alt = []
    if l < 0x10000
      alt << ["alt", alt_ranges(l, [r, 0xFFFF].min, 4, 4)]
    end
    if r >= 0x10000
      l1 = [l, 0x10000].max - 0x10000
      r1 = r - 0x10000
      do_range(l1, r1, 10) do |l2, r2, column|
        alt << ["seq",
                alt_ranges((l2 >> 10) + 0xD800, (r2 >> 10) + 0xD800, 4, 4),
                expand_string("\\u"),
                alt_ranges((l2 & 0x3FF) + 0xDC00, (r2 & 0x3FF) + 0xDC00, 4, 4)]
      end
    end
    wrap_flat("alt", alt)
  end

  def alt_ranges_modern(l, r, step = 4)
    ["seq",
     expand_string("{"),
     ["rep", 0, true, ["cs","0"]],
     alt_ranges(l, r, 4, false),
     expand_string("}")]
  end

  # flatten_strings: reduce all strings to char-range/seq/alt

  def expand_string(s, case_fold = false)
    wrap("seq",
         s.chars.map do |ch|
           if case_fold &&
              (u = ch.upcase; d = ch.downcase; u != d)
             ["alt", expand_string(u), expand_string(d)]
           else
             ["char-range", ch, ch]
           end
         end)
  end

  def flatten_strings_1(prod)
    f1 = visit(prod) do |here|
        case here
        in ["cs", string]
          [true, expand_string(string, false)]
        in ["ci", string]
          [true, expand_string(string, true)]
        else
          false
        end
    end
    merge_strings_1(flatten_ops_1(f1))
  end


  def merge_strings_1(prod)
    visit(prod) do |here|
      case here
      in ["alt", *rest]
        ranges = []
        i = 0
        while i < rest.size
          case rest[i]
          in ["char-range", _ic1, _ic2]
            j = i
            while j+1 < rest.size && (rest[j+1] in ["char-range", _jc1, _jc2])
              j += 1
            end
            ranges << [i, j] if i != j # inclusive right
            i = j
          else
            here[i+1] = merge_strings_1(rest[i]) # XXX could be part of a range
          end
          i += 1
        end
        ranges.reverse.each do |i, j|
          sorted = here[i+1..j+1].sort
          l = sorted.length
          while l > 1
            l -= 1              # index to last item
            if sorted[l][1].ord == sorted[l-1][2].ord+1 # merge:
              sorted[l-1..l] = [["char-range", sorted[l-1][1], sorted[l][2]]]
            end
          end
          here[i+1..j+1] = sorted
        end
        [true, here]
      else
        false
      end
    end
  end

  def flatten_strings
    rules.each do |name, prod|
      rules[name] = flatten_strings_1(prod)
    end
  end

end

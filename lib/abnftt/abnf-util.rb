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

  def do_ranges_outside(cr, l, r)
    if cr[2] < l || cr[1] > r # outside
      yield cr[1].ord, cr[2].ord
    else
      if cr[1] < l
        yield cr[1].ord, l.ord - 1
      end
      if cr[2] > r
        yield r.ord + 1, cr[2].ord
      end
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
    wrap("alt", alt.reverse)    # work around prioritized choice
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

  # Cleanup operations

  def expand_range_into(s, op, out = [op])
    s.each do |el|
      case el
      in [^op, *inner]
        expand_range_into(inner, op, out)
      else
        out << char_range_to_string1(el)
      end
    end
    out
  end
  def char_range_to_string1(prod)
    visit(prod) do |here|
        case here
        in ["seq", *rest]
          rest = expand_range_into(rest, "seq")
          i = rest.size
          while i > 1
            if (rest[i-1] in ["cs", s2]) && (rest[i-2] in ["cs", s1])
              rest[i-2..i-1] = [["cs", s1 + s2]]
            end
            i -= 1
          end
          [true, rest]
        in ["char-range", chr, ^chr] if chr.between?(" ", "!") || chr.between?("#", "~")
          [true, ["cs", chr]]
        else
          false
        end
    end
  end
  def char_range_to_string
    rules.each do |name, prod|
      rules[name] = ci_cs_merge(detect_ci(char_range_to_string1(prod)))
    end
  end

  def detect_ci(prod)
    visit(prod) do |here|
        case here
        in ["alt", ["cs", c1], ["cs", c2]] if c1.downcase == c2 && c2.upcase == c1
          [true, ["ci", c1]]
        else
          false
        end
    end
  end
  def ci_compat(prod)
    case prod
    in ["ci", s]
      s
    in ["cs", s] if s =~ /\A[^A-Za-z]*\z/
      s
    else
      nil
    end
  end
  def ci_cs_merge(prod)
    visit(prod) do |here|
        case here
        in ["seq", *rest]
          rest = rest.map{|x| ci_cs_merge(x)}
          i = rest.size
          while i > 1
            if (s2 = ci_compat(rest[i-1])) && (s1 = ci_compat(rest[i-2]))
              rest[i-2..i-1] = [["ci", s1 + s2]]
            end
            i -= 1
          end
          [true, wrap_flat("seq", rest)]
        else
          false
        end
    end
  end

  def seq_rep(prod)
    visit(prod) do |here|
        case here
        in ["seq", *rest]
          rest = rest.map{|x| seq_rep(x)}
          i = rest.size         # behind last element
          while i > 1
            j = i - 1           # end of range
            s_end = rest[j]
            k = j               # start of range
            while k > 0 && rest[k-1] == s_end
              k -= 1
            end
            if k != j
              n = j - k + 1
              rest[k..j] = [["rep", n, n, s_end]]
            end
            i = k               # skip element k
          end
          [true, wrap_flat("seq", rest)]
        else
          false
        end
    end
  end

  # sharing
  def count_alt(counter, prod)
    visit(prod) do |here|
      case here
      in ["alt", *rest]
        rest.each {|pr| count_alt(counter, pr)}
        counter[here] += 1
      else
        false
      end
    end
  end

  def share_alt(prefix)
    counter = Hash.new(0)
    rules.each do |name, prod|
      count_alt(counter, prod)
    end
    subs = {}
    counter.to_a.select{|k, v| v > 2}.sort_by{|k, v| -v}.each_with_index do |(el, _count), i|
      name = "#{prefix}-a#{i}"
      rules[name] = el
      subs[el] = name
    end
    rules.each do |name, prod|
      count_alt(counter, prod)
    end
    rules.replace(Hash[rules.map do |k, v|
                    [k, seq_rep(visit(v) do |prod|
                       if (s = subs[prod]) && k != s
                         [true, s]
                       end
                     end)]
                  end])
    replacements = Hash[
      rules.map{|k, v|
        [v, k] if String === v && /^sq-a\d+$/ === v
      }.compact]
    # warn [:REPLA, replacements].inspect
    used = {}
    used[rules.first.first] = true
    rules.each do |k, v|
      visit(v) do |here|
        if String === here
          if r = replacements[here]
            used[r] = true
          else
            used[here] = true
          end
        end
      end
    end
    # TODO: Should not do a h-x09
    # warn [:USED, used].inspect
    rules.replace(Hash[rules.map {|k, v|
                         unless replacements[k] || !used[k]
                           if r = replacements[v]
                             v = rules[v]
                           end
                           v = visit(v) do |here|
                             if String === here && (r = replacements[here])
                               # warn [:R, v, r].inspect
                               [true, r]
                             end
                           end
                           [k, v]
                         end
                       }.compact])
  end

  def share_hex_1(prod, rules)
    visit(prod) do |here|
      case here
      in ["alt",
          ["char-range", c3l, "9"],
          ["char-range", "A", c4r],
          ["char-range", "a", c6r]] if c4r == c6r.upcase && c3l >= "0" && c6r <= "f"
        name = "x#{c3l}#{c6r}"
        rules[name] ||= here
        [true, name]
      in ["alt",
          ["char-range", c4l, c4r],
          ["char-range", c6l, c6r]] if c4r == c6r.upcase &&
                                       c4l == c6l.upcase &&
                                       c6l.between?("a", "f") &&
                                       c6r.between?("a", "f")
        name = "x#{c6l}#{c6r}"
        rules[name] ||= here
        [true, name]
      # in ["char-range", l, r] if l >= "0" && r <= "9"
      #   name = "x#{l}#{r}"
      #   rules[name] ||= here
      #   [true, name]
      in ["seq", ["cs", "\\u"], *rest]
        suff = "0"
        rest = rest.map {|r| share_hex_1(r, rules) }
        case rest
        in [["alt", [/^c./, hex], *], *]
          name = "u-#{hex}"
          while rules[name] && rules[name] != here
            name = "u-#{hex}-#{suff.succ!}"
          end
        in [["alt", ["seq", [/^c./, hex], *], *], *]
          name = "u-#{hex}x"
          while rules[name] && rules[name] != here
            name = "u-#{hex}x-#{suff.succ!}"
          end
        else
          # require 'neatjson'
          # warn ::JSON.neat_generate(here)
          name = "u-#{suff.succ!}"
          while rules[name] && rules[name] != here
            name = "u-#{suff.succ!}"
          end
        end
        rules[name] ||= here
        [true, name]
      else
        false
      end
    end
  end

  def share_hex(_prefix)
    newrules = {}
    rules.each do |name, prod|
      rules[name] = share_hex_1(prod, newrules)
    end
    rules.merge!(Hash[newrules.sort])
  end
end

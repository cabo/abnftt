# abnftt: PEG-parsing using ABNF grammars

`abnftt` translates a grammar in an augmented ABNF syntax into a [treetop][]
grammar that can be compiled into a PEG parser.

[treetop]: https://github.com/cjheath/treetop

Installation: `gem install abnftt`

Usage:

```
  abnftt mygrammar.abnftt
```

generates three files:

* `mygrammar.abnf` -- a copy of the pure ABNF in the abnftt file, with
  the "semantic predicates" (treetop term) removed.
* `mygrammar.treetop` -- a translation of the augmented ABNF in the
  abnftt file to the treetop grammar format.
* `mygrammar.yaml` -- a YAML representation of the parse tree of the
  augmented ABNF file.

  Use `tt mygrammar.treetop` to obtain a `mygrammar.rb`.

An example for the use of `abnftt` is available in the [cddlc][] gem.

[cddlc]: https://github.com/cabo/cddlc

# abnfrob: ABNF processing tool

`abnfrob` is intended as a general tool for processing and converting
ABNF grammars.

Its basic function is reading and parsing an ABNF file and writing an equivalent
one based on the parse tree.

As of today, it provides only one processing function that can be
performed on the parse tree before writing the output ABNF file:
*[Squashinating][]*.

[Squashinating]: https://www.ietf.org/archive/id/draft-ietf-cbor-edn-literals-14.html#appendix-B

If you have a `cbor-edn-h.abnf` like this:

``` abnf
app-string-h    = S *(HEXDIG S HEXDIG S / ellipsis S)
                 ["#" *non-lf]
ellipsis        = 3*"."
HEXDIG          = DIGIT / "A" / "B" / "C" / "D" / "E" / "F"
DIGIT           = %x30-39 ; 0-9
blank           = %x09 / %x0A / %x0D / %x20
non-slash       = blank / %x21-2e / %x30-10FFFF
non-lf          = %x09 / %x0D / %x20-D7FF / %xE000-10FFFF
S               = *blank *(comment *blank )
comment         = "/" *non-slash "/"
               / "#" *non-lf %x0A
```

…calling

```
   abnfrob --squash=h cbor-edn-h.abnf
```

gives you this `cbor-edn-h-sq.abnf` (manually line-broken for readability):

```
sq-h-app-string-h = %s"h'" h-app-string-h "'"
h-app-string-h = h-S *(h-HEXDIG h-S h-HEXDIG h-S / h-ellipsis h-S)
    [("#" / %s"\u" ("0023" / "{" *("0") "23}")) *(h-non-lf)]
h-ellipsis = 3*("." / %s"\u" ("002E" / "{" *("0") "2E}"))
h-HEXDIG = h-DIGIT
    / %x41-46 / %s"\u" ("004" %x31-36 / "{" *("0") "4" %x31-36 "}")
    / %x61-66 / %s"\u" ("006" %x31-36 / "{" *("0") "6" %x31-36 "}")
h-DIGIT = %x30-39 / %s"\u" ("003" %x30-39 / "{" *("0") "3" %x30-39 "}")
h-blank = %x0a / %s"\n" / %s"\r" / %s"\t"
    / %s"\u" ("000" ("9" / %s"A" / %s"a") / "{" *("0") ("9" / %s"A" / %s"a") "}")
    / %s"\u" ("000D" / "{" *("0") "D}") / " " / %s"\u" ("0020" / "{" *("0") "20}")
h-non-slash = h-blank / %x21-26 / %x28-2e / "\'"
    / %s"\u" ("002" h-x1e / "{" *("0") "2" h-x1e "}")
    / %x30-5b / %x5d-d7ff / %xe000-10ffff / "\\"
    / %s"\u" (h-x1f 3(h-x0f) / "0" h-x1f 2(h-x0f) / "00" h-x3f h-x0f
        / "D" h-x8b 2(h-x0f) %s"\u" "D" h-xcf 2(h-x0f)
        / "{" *("0") ("10" 4(h-x0f) / h-x1f 4(h-x0f)
            / h-x1f 3(h-x0f) / h-x1f 2(h-x0f) / h-x3f h-x0f) "}")
h-non-lf = %s"\t" / %s"\u" ("0009" / "{" *("0") "9}") / %s"\r"
    / %s"\u" ("000D" / "{" *("0") "D}") / %x20-26 / %x28-5b
    / %x5d-d7ff / "\'" / "\/" / "\\"
    / %s"\u" ("D" %x30-37 2(h-x0f) / h-x1c 3(h-x0f)
        / "0" h-x1f 2(h-x0f) / "00" h-x2f h-x0f
        / "{" *("0") ("D" %x30-37 2(h-x0f) / h-x1c 3(h-x0f)
                    / h-x1f 2(h-x0f) / h-x2f h-x0f) "}")
    / %xe000-10ffff
    / %s"\u" (h-xef 3(h-x0f) / "D" h-x8b 2(h-x0f) %s"\u" "D" h-xcf 2(h-x0f)
        / "{" *("0") ("10" 4(h-x0f) / h-x1f 4(h-x0f) / h-xef 3(h-x0f)) "}")
h-S = *(h-blank) *(h-comment *(h-blank))
h-comment = ("/" / "\/" / %s"\u" ("002F" / "{" *("0") "2F}"))
        *(h-non-slash) ("/" / "\/" / %s"\u" ("002F" / "{" *("0") "2F}"))
    / ("#" / %s"\u" ("0023" / "{" *("0") "23}"))
        *(h-non-lf) (%x0a / %s"\n" / %s"\u" ("000A" / "{" *("0") "A}"))
h-x0f = %x30-39 / %x41-46 / %x61-66
h-x1c = %x31-39 / %x41-43 / %x61-63
h-x1e = %x31-39 / %x41-45 / %x61-65
h-x1f = %x31-39 / %x41-46 / %x61-66
h-x2f = %x32-39 / %x41-46 / %x61-66
h-x3f = %x33-39 / %x41-46 / %x61-66
h-x8b = %x38-39 / %x41-42 / %x61-62
h-xcf = %x43-46 / %x63-66
h-xef = %x45-46 / %x65-66

```

In the main EDN grammar, you can amend `app-string` to

```
   app-string      = sq-h-app-string-h / app-prefix sqstr
```

...in the main ABNF to make use of this.

If you don't want to do your own line-breaking, but your screen is
narrow (or you want to include the result in an RFC), you might want
to try:

```
   abnfrob -a --squash=h cbor-edn-h.abnf
```

(`-a` == `--asr33`) and you get some (not so great) automatic linebreaking.

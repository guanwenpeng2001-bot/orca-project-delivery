---
name: localization
description: Prepare source copy so placeholders, plural rules, and right-to-left layout survive translation. Use when shipping text that will be translated or pseudo-localized. Not for writing the translation itself.
---

# Localization

## Core principle

Translation changes the words and must not change the structure around them. Anything the program reads back out of a sentence — a placeholder, a tag, a count — has to be marked so a translator cannot break it by accident, and the layout has to survive a sentence that comes back longer and in the other direction.

## Decision criteria

Build the glossary before the string list. One term, one translation, decided by the people who own the domain language. Translate the glossary first and reuse it, so the same action does not become three verbs across one product.

Write messages as complete sentences with named placeholders, never as fragments concatenated in code. Word order moves between languages, so `Saved` + name + `items` cannot be repaired downstream.

| Construct | Rule | Reject |
| --- | --- | --- |
| Placeholder | Numbered or named, typed where the format allows: `{name}`, `%1$s` | An unescaped `%` or `{` that is not a placeholder |
| ICU plural | `plural` with every category the target language requires, and `other` always | A binary `1 item` / `n items` branch in code |
| Tags | Named XML-style tags for emphasis, not split strings | Emphasis carried by word order or color alone |
| Direction | Layout uses logical properties (`margin-inline-start`) and isolates inserted values with the unicode isolates | `left`/`right` used to mean start/end |

ICU `plural` selects on the operand, not on a guess that "anything but one is plural". Arabic needs `zero`, `one`, `two`, `few`, `many`, and `other`; a string that only supplies `one` and `other` is wrong there even though it looks finished in English. Keep the number inside the translated text so the translator controls its position: `{count, plural, one {# file} other {# files}}`.

Quote every brace and hash that should appear literally. In ICU, a literal `{` is `'{`}`. An unquoted brace is a placeholder whether or not one was intended.

Right-to-left layout: set direction from the locale, not from a per-language stylesheet branch. Use logical CSS properties. Wrap a value whose direction differs from the sentence, such as an English identifier inside Arabic prose, in unicode isolates (U+2066 and U+2069) so it does not reorder its neighbors. Mirror icons that point forward; do not mirror icons that depict an object.

Pseudo-localization is the pre-translation check. Expand every vowel, wrap the string in brackets, and flip direction. If the UI clips, overlaps, or shows a raw `{name}`, fix the source. Pseudo-localization is not a translation and does not count as one.

A translation memory belongs to the product and the glossary, not to a vendor account. Record the source sentence, the locale, the approved translation, and the glossary version it used.

### What this does not do

This method prepares and checks source copy. It does not call a translation service, and it does not invent translations. `product-design` owns the interaction states the copy appears in; this Skill owns the strings and their direction.

## Workflow

1. Freeze the glossary for the terms in scope, with the retired synonyms.
2. Rewrite concatenated fragments as full messages with named placeholders.
3. Replace count branches with ICU `plural`, including `other` and the categories the target locales require.
4. Mark literals and isolate bidirectional values.
5. Run pseudo-localization and record clipping, raw placeholders, and direction bugs.
6. Compare the two locale files: same keys, same placeholders per key, no key present on only one side.

## Worked example

Source, before:

```text
label = "Saved " + count + " files to " + folder
```

Arabic cannot reorder that, and `count == 1` is the wrong plural test.

After, one message key `save.summary`:

```text
{count, plural, one {Saved # file to {folder}} other {Saved # files to {folder}}}
```

The Arabic message for the same key uses `zero`, `one`, `two`, `few`, `many`, and `other`, and keeps `{folder}` exactly. The English and Arabic files must have the same keys and the same placeholder set per key. `{folder}` missing on one side fails the check even if the sentence reads well.

Pseudo-localized English renders as `[Šävëð # fïlë tö {folder}]` with the direction flipped. The brackets expose clipping, the accented letters expose a font that cannot carry them, and a visible `{folder}` exposes interpolation that never ran. `examples/messages.json` holds the key in both locales plus the broken twin that drops `{folder}` in Arabic.

From the package root:

```sh
node --test skills/localization/examples/message-consistency.test.mjs
```

## Failure signals

- Sentences are built by concatenating translated fragments.
- Pluralization is `count === 1`.
- A target locale receives only `one` and `other` when its plural rules need more.
- A literal brace reaches a translator unquoted.
- Direction is implemented as `margin-left` swaps per locale.
- An inserted identifier reorders the words around it.
- Two locale files disagree on keys or placeholder sets.
- A translation was produced by calling a service from this Skill.

## Evaluation scenario

Given `save.summary` in English and Arabic where the Arabic message omits `{folder}`, the result should fail bilingual consistency, name the missing placeholder, and confirm the English message uses `plural` with `other` rather than a `count === 1` branch. It fails the method if the Arabic sentence is rewritten as a translation, or if the check only compares the two strings for equal length.

## Output

- Glossary delta
- Message keys with placeholders and plural categories
- Pseudo-localization findings
- Key and placeholder parity across locales
- Direction and isolation decisions

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. It does not translate copy, call a machine-translation service, or upload text. Product direction, scope, and irreversible choices stay with the user.

---
name: infographic-design
description: Turn verified quantities into a readable infographic layout and generation brief. Use before rendering a data graphic.
---

# Infographic Design

## Core principle

An infographic encodes quantities that have already been verified. Layout cannot invent missing numbers, and a picture of text is not a data source.

## Decision criteria

Choose the chart form from the comparison being made. Categories compare with bars, time uses a line, and part-to-whole uses shares that total the stated whole. A decorative metaphor is allowed only after the quantitative encoding is readable on its own.

Label every value and unit directly where possible. A legend that requires constant eye movement fails when there are few series. Sort bars by value or by a named domain order, and start quantitative bar axes at zero. A truncated axis must be explicit and is normally the wrong choice for bars.

The generation brief specifies canvas size, title, source, palette, and exact text. It also lists facts the image must not add. If an image model renders the graphic, its output is checked against the source values and rejected for changed numbers. The brief itself is not the finished infographic.

Use colorblind-safe distinctions and contrast of at least 4.5:1 for text. Do not encode a series by color alone when shape or direct labels can identify it.

### Reference

The method is original. Graphical integrity and zero-baseline guidance follow Edward Tufte, *The Visual Display of Quantitative Information*, and contrast follows WCAG 2.2: https://www.w3.org/TR/WCAG22/

## Workflow

1. Collect the source figures, units, date, and permitted rounding.
2. Select the form and draw a text-level layout with all labels.
3. Define the image brief and prohibited alterations.
4. After rendering, compare every visible number with the source.
5. Reject any output that adds a trend, icon, or annotation not in the brief.

## Worked example

Three berths handled 12, 18, and 9 vessels. The layout is a horizontal bar chart sorted descending, labeled “Vessels in March 2026,” with values beside bars and a zero baseline. The brief permits blue, teal, and gray and forbids a claim about profit. A rendered image that changes 18 to 19 or adds “record growth” is rejected even if the composition looks polished.

## Failure signals

- The source data has no date, unit, or total where shares are shown.
- Bars begin above zero without an explicit warning.
- The rendered text differs from the brief and is accepted.
- A metaphor obscures the order or magnitude of the values.

## Evaluation scenario

Given three sourced values, the result names the form, axis rule, exact labels, and a rejection example for altered text. It fails if it proceeds from an unstated number.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.

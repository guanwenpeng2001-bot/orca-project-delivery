---
name: visual-slide-deck
description: Plan a visual slide sequence and label rendered images as non-editable pictures. Use for image-based decks rather than Office objects.
---

# Visual Slide Deck

## Core principle

A visual deck is a sequence of pictures with a reading order. It must be labeled as image content and not presented as editable presentation objects.

## Decision criteria

Give each slide one claim and one visual action. A slide with two claims should be split. The title states the claim; the body supplies the evidence or next action rather than repeating the title.

Plan for the projection size. Body text must be readable at the back of the intended room, and contrast must meet ordinary text requirements. A full-bleed image needs a protected area for text. Do not place necessary text inside an image region where cropping or generation may alter it.

If slides are rendered by an image model, every required word is listed exactly and checked after rendering. Numbers and names are source-controlled text, not improvised decoration. Exporting the images into a presentation shell does not make their text editable; the delivery note must say that plainly.

Use the document-production method when the user needs editable text, data, or vector objects. Do not route that request through a picture deck merely because the visual result looks similar.

### Reference

The method is original. Readability and slide-claim guidance derives from presentation practice and WCAG contrast: https://www.w3.org/TR/WCAG22/

## Workflow

1. Write the claims in sequence before rendering.
2. Mark text that must survive exactly and text that is decorative.
3. Render only under the image task’s authorization.
4. Read every slide back against the claim list.
5. Label the delivery as image-based and name any editable alternative.

## Worked example

Five harbor-review slides each carry one claim: status, cause, cost, action, and owner. The cost slide lists “$42,000” as required text. After rendering, that word is compared character for character. The delivery states “PNG slides, not editable presentation objects.” A slide combining cause and cost is split before rendering.

## Failure signals

- A slide contains multiple unrelated claims.
- Required text is wrong but described as close enough.
- The image deck is called editable because it was inserted into presentation software.
- Contrast or viewing distance was never specified.

## Evaluation scenario

Given five claims, the result has one claim per slide, an exact-text check, and an image-format disclosure. It fails if it promises object-level editing.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.

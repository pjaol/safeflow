# Clio Daye — App Icon Design Prompt

## Concept

Clio Daye is a woman's name. The icon IS the brand identity — she is every woman who uses the app.

A half-face portrait rendered in Trompe-l'oeil style. The face is not drawn — it is BUILT from overlapping geometric circles and arcs that create the illusion of a face through their arrangement and color. The overlapping forms evoke the cycle arcs and orbital phases from the app's data visualizations — the design language of the app IS the face.

The half-face is deliberate: mystery, incompleteness, the unseen half suggests interiority and privacy (core to the app's values). The other half is yours — the user completes her.

## Final Generation Prompt (nano-banana / Gemini Pro)

```
iOS app icon artwork for 'Clio Daye', a premium women's cycle tracking app.
IMPORTANT: The face must fill 90% of the canvas — cropped in close, intimate,
no empty space around it.

The face: a woman's face constructed from overlapping translucent geometric
circles and arcs, split vertically down the center. The face is CROPPED TIGHT
— forehead to chin just fits, left edge to right edge of face fills nearly the
full width. This is a close portrait, not a distant figure.

Left half of face: peachy warm light skin tones, large soft overlapping
circles. Right half: deeper warm brown skin tones, a teal-shadow eye socket,
one calm direct almond eye. The vertical split line runs down the nose bridge.
Overlapping circles blend at edges creating mixed tones — light peachy rose,
warm golden brown, deep brown-bronze. No hard outlines.

Background: the tiny amount of background visible is a soft gradient — sky
blue (#A8DFF7) top, warm coral-pink (#FEC8D8) bottom-left, pale yellow
(#FFF5C3) bottom-right. Bleeds to all four edges, no padding, no border, no
card frame.

The face should be so close that the top of the forehead and the chin are
nearly touching the top and bottom edges of the image. Think passport photo
distance, not full-body. Premium, confident, intimate.
```

## Parameters

- Tool: nano-banana (Gemini 3 Pro)
- Size: 4K
- Aspect: 1:1
- Reference: clio-icon-edgetoedge.jpeg (previous iteration)
- Output: clio-icon-zoomed.jpeg → used as final app icon

## Design Rationale

- **Skin tone layering**: Three tones (light peachy rose, warm golden brown,
  deep brown-bronze) are structurally integral to the geometry — diversity
  baked into the trompe-l'oeil construction, not applied cosmetically
- **No card/frame**: iOS applies its own rounded corner mask; artwork bleeds
  edge to edge
- **App palette**: Background gradient uses the app's exact colors (#A8DFF7,
  #FEC8D8, #FFF5C3) so the icon coordinates with the UI
- **Mood**: Confident, private, not performing. Premium health tech, not a
  period tracker that apologizes for existing

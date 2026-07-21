# Noto Sans SC

These static font files are pinned instances of the official Google Fonts
`NotoSansSC[wght].ttf` variable font:

https://github.com/google/fonts/tree/main/ofl/notosanssc

They are generated at weights 400, 500, 600, and 700 so Flutter can select
the intended face through `TextStyle.fontWeight`. The source variable font has
a default `wght` axis value of 100, so registering it as one unqualified asset
causes some desktop fallback paths to render Chinese text as Thin.

Generation command, using fonttools:

```sh
fonttools varLib.instancer NotoSansSC-VariableFont_wght.ttf wght=400 \
  --output=NotoSansSC-Regular.ttf
```

Repeat with 500/Medium, 600/SemiBold, and 700/Bold. The font is distributed
under the SIL Open Font License included in `OFL.txt`.

# flutter_tipkit demo

A chapter for each feature, from the simplest tip to the most involved:

1. **Basics:** an inline tip, popovers that take turns, and actions.
2. **Rules:** an event, a parameter, and a tip some time after another.
3. **Flow:** a tour across several widgets, a display limit, and
   suppressing every tip for a while.
4. **Look:** the same tips with the default card, a theme, and a card of
   your own.

Each chapter shows its code and the tip events it causes. The inspector, in
the app bar, lists every tip's status live, and the reset button starts
every tip over.

Try it online at https://poopieapp.github.io/flutter_tipkit/, or run it:

```sh
flutter run -d chrome
```

The tips are in [lib/tips.dart](lib/tips.dart), the chapters in
[lib/chapters](lib/chapters).

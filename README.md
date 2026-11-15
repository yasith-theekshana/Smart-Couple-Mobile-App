# Smart Couple — Flutter mobile app

Native Flutter recreation of the mobile demo in:
https://github.com/yasith-theekshana/Smart-Couple-Mobile-App-Website

Reference: `src/pages/test/MobileAppTest.tsx` and its mobile screen components.
The React website's desktop pages are separate from this mobile interface.

## Run

```sh
flutter pub get
flutter run
```

## Included

- Royal blue/gold/cream theme, bundled Inter and Playfair Display fonts, reference artwork.
- Home with responsibility tiles and relationship articles.
- Finance dashboard, editable partner contributions, expenses, debt tracking, spending breakdown.
- Shopping lists with quantities, unit prices, checkboxes, editing, and list switching.
- Household tasks with assignments, categories, completion filters, dates, and weekly recurrence.
- Calendar showing shared tasks, monthly recurring expenses, and custom events.
- French/English switching through the profile button.

The demo starts in April 2026 to display the source project's sample data.
Data is held in memory and resets when the app restarts. Authentication,
persistent storage, partner synchronization, notifications, and payments are
not implemented. Native layouts and forms adapt the reference rather than
embedding React in a WebView. Some advanced React controls (custom categories,
split expense entry, weekly task navigation, and profile photo switching) are
not ported.

## Validate

```sh
flutter analyze
flutter test
```

`lib/main.dart` contains the application screens and shared state.
`lib/ui.dart` contains styles, models, and validated input sheets.
`lib/articles.dart` contains the article list and reader.

## Assets

The logo and article/profile artwork follow the linked reference repository.
Photo sources include Unsplash, Pexels, and Lune Baroque, as used in that source.
Fonts come from Google Fonts; their SIL Open Font License texts are included in
`assets/fonts/Inter-LICENSE.txt` and `assets/fonts/Playfair-LICENSE.txt`.

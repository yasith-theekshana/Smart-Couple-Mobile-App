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
Dashboard demo data is held in memory and resets when the app restarts. Firebase
authentication and user profiles are implemented; shared finance/task persistence,
partner synchronization, notifications, and payments are not implemented. Native layouts and forms adapt the reference rather than
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

## Firebase

Firebase Core is configured for project `smart-couple-app` on Android and web.
The app initializes Firebase before showing its home screen. Android uses package
`com.smartcouple.smart_couple`. Configuration is in `lib/firebase_options.dart`,
`android/app/google-services.json`, and `firebase.json`.

To regenerate configuration after adding platforms or Firebase products:

```powershell
firebase login
& "$env:LOCALAPPDATA\Pub\Cache\bin\flutterfire.bat" configure --project=smart-couple-app --platforms=android,web
```

Firebase email/password authentication and private Firestore user profiles are
implemented. See [authentication setup and tests](docs/AUTHENTICATION.md).
Dashboard demo data still resets on restart. Other desktop/iOS
platforms need FlutterFire configuration before running the app on those targets.

## Couple spaces

Create Couple Space now saves a named, private space and atomically links its creator.
The profile listener opens the dashboard, which displays the saved space name.
Join/invitations remain a future phase. See [couple-space implementation and tests](docs/COUPLE_SPACES.md).

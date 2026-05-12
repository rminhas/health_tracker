# Health Tracker

A personal health tracking app for iOS and Android built with Flutter.

## What it does

**Food logging** — Log meals by scanning a barcode, searching the USDA FoodData Central database, entering details manually, or picking from previously logged foods. Each entry is assigned a meal category (Breakfast, Lunch, Dinner, Snack) pre-selected based on the time of day. Amount can be entered in g, oz, lbs, ml, or cups; everything is stored in grams internally. Entries can be edited after logging.

**Dashboard** — Shows a daily summary with a calorie progress ring (green when under target, red when over), macronutrient totals, calories burned via exercise, and today's meals grouped by category. Individual workout activities imported from Apple Health / Health Connect appear in a dedicated Exercise section.

**Weight tracking** — Log weight from a quick-access button on the dashboard. Weight syncs automatically to Apple Health (iOS) or Health Connect (Android). Target weight and weekly loss/gain rate can be set, and the app calculates the required daily calorie deficit or surplus.

**Analytics** — Calendar view (week by default) where tapping a day shows that day's food log and calorie total. Macronutrient charts include a pie/bar chart of fat/protein/carb split and a stacked bar chart of daily breakdown over the last 7 days. Weight progression chart shows current weight against the target.

## Tech stack

| Concern | Solution |
|---|---|
| Framework | Flutter (iOS + Android) |
| Local storage | SQLite via `sqflite` |
| Food search | USDA FoodData Central API |
| Barcode lookup | Open Food Facts API |
| Health data | Apple HealthKit (iOS) / Health Connect (Android) |
| State management | Provider |

## Running the app

```bash
flutter pub get
flutter run
```

Requires a physical device for barcode scanning and health data access.

## Running tests

```bash
flutter test
```

75 unit tests covering food log model, unit conversions, meal types, provider behaviour, barcode check-digit validation, and search caching.

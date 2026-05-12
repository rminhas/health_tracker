# A Health Tracker - BRD
This app is intended for a person who wants to track their health metrics.

# Features
## User can
- Log the food they consume
    - by scanning barcode
    - by searching in the database (results populate dynamically as the user types)
    - by entering the nutritional information manually
    - by picking from previously logged foods
    - each food entry is assigned to a meal category: Breakfast, Lunch, Dinner, or Snack; the category is pre-selected based on the time of day but can be changed
    - the daily meals log on the dashboard groups entries by meal category in chronological order; legacy entries with no category appear under "Other"
    - ability to specify/change the amount of food being added
        - unit of the amount can be changed between g, oz, lbs, ml, and cups; the amount is converted to grams internally before saving
        - volume units (ml, cups) display a note that conversion assumes a density of 1 g/ml and is most accurate for liquids
    - ability to edit the amount of food ingested in a log entry after it has been made, with the same unit picker (g, oz, lbs, ml, cups) available during logging
- Automatically import exercise data from Apple Health and Google Fit
    - individual workout activities (e.g. cycling 20 min, walking 10 min) are shown in a dedicated Exercise section below the daily meals log
- Log their weight via a quick-access button, which automatically syncs to Apple Health
- Change the weight unit preference between kg and lbs (all weight inputs and displays adapt, including the weight log dialog, profile/goals screen, and weight chart)
- Set a target weight and create a weight loss/gain plan
    - they can define the loss/gain rate per week
    - the app will calculate the required daily calorie deficit/surplus
    - the app will infer the base daily calorie consumption based on the weight, height, age, biological sex
    - the app will infer the daily calorie burn based on the exercise data from Apple Health and Google Fit
    - the app will adjust the daily calorie deficit/surplus based on the user's progress
    - the app will adjust the weight loss/gain rate based on the user's progress
- View the calories consumed, burned, and net calories
    - a circular progress ring on the dashboard shows calories consumed vs. target at a glance; the ring fills green when under target and red when over
- View their health metrics
- View their health metrics in a chart
    - weight progression chart that shows the current weight target
- View their health metrics in a calendar
    - tapping a day shows a bottom sheet with that day's food log entries and calorie total
- View statistical summaries of macronutrients
    - average daily calorie consumption over the last week, month, and year
    - pie chart or bar chart showing the split of calories from fat, protein, and carbohydrates
    - stacked bar chart showing daily macronutrient breakdown over the last 7 days
- View their health metrics in a weekly/monthly report
- Automatically infer the nutritional information of food from public databases like NCCDB
    - the food data should be stored locally and should be updated periodically
    - search results are cached locally in SQLite (keyed by query, 24-hour TTL) so the app works without internet and repeat searches are instant; stale entries are pruned automatically

# Implementation Details
- The app will be implemented as a mobile app using Flutter
- The app will use SQLite as the database
- The app will use Apple HealthKit for iOS and Google Fit for Android for health data
- The app will use FoodData Central API for food data
- 
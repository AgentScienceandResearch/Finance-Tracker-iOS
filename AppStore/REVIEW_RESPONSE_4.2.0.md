# App Review response — version 4.2.0, build 18

## Reply to App Review

Hello App Review,

Thank you for the feedback. Version 4.2.0, build 18 addresses each issue:

- Guideline 5.1.1(v), account deletion: A signed-in user can open Settings > Account > Delete Account and permanently delete the account in the app. The flow requires an explicit confirmation and, when applicable, password or Sign in with Apple reauthentication. It deletes the Firebase Authentication account, the user's cloud profile and finance data, and the on-device cache associated with that account. The screen also explains that deleting an account does not cancel an App Store subscription and provides a direct Manage Subscriptions link.
- Guideline 5.1.1(v), login requirement: Registration is no longer required for the finance tracker. On a fresh launch, the app opens directly to the tracker and stores the user's data locally. A "Sign In" action is visible on the dashboard and at the top of Settings > Account for users who want cloud sync.
- Guideline 2.3.2, promotional images: App Store promotion was disabled for the affected subscription, and the duplicate promotional images were removed from the new monthly and yearly subscription metadata versions.

Physical-device screen recording: **[REPLACE WITH PUBLICLY ACCESSIBLE RECORDING URL]**

The recording demonstrates a fresh launch without login, account creation or sign-in, navigation to Settings > Delete Account, the complete deletion flow, and the deletion confirmation.

## App Review Notes field

Build 18 permits full local use without registration. Optional cloud accounts can be permanently deleted at Settings > Account > Delete Account.

Physical-device screen recording: **[REPLACE WITH PUBLICLY ACCESSIBLE RECORDING URL]**

The video shows: fresh launch into the local tracker without login; account creation/sign-in; navigation to the deletion option; confirmation and reauthentication; successful permanent account deletion.

## Physical-device recording checklist

Record one continuous video on a physical iPhone:

1. Delete the previous app installation so the recording starts from a fresh install.
2. Install version 4.2.0, build 18 through TestFlight or Xcode.
3. Launch the app and show that the finance dashboard opens without a registration or login screen.
4. Optionally add one local transaction to make local access especially clear.
5. Tap **Sign In** on the dashboard, or open it from Settings > Account.
6. Create a disposable email/password account, or sign in to the demo account supplied to App Review.
7. Return to Settings and show the signed-in Cloud Sync state.
8. Tap **Delete Account**.
9. Show the permanent-deletion explanation and the App Store subscription notice.
10. Type `DELETE`, enter the current password or complete Sign in with Apple confirmation, and tap **Permanently Delete Account**.
11. Confirm the destructive alert and wait for the success confirmation.
12. Show that the app returns to on-device mode and offers **Sign In** again.

Upload the video somewhere App Review can open without requesting access, then replace both recording URL placeholders above.

## Resubmission checklist

- Archive and upload version 4.2.0, build 18.
- Select build 18 for the rejected App Store version.
- Include the image-free version 2 metadata drafts for both active subscriptions in the submission.
- Verify the yearly promoted purchase remains disabled and hidden from all users.
- Paste the response above into the resolution-center reply.
- Paste the shorter note and recording URL into App Review Information > Notes.
- Ensure App Review has working demo credentials if the recording uses a demo account.
- Submit the app version and affected subscription metadata for review together.

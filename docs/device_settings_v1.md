# DEVICE SETTINGS V1

SYSTEM → DEVICE SETTINGS configures OR-APP only. Preferences are stored as
`or_app_device_settings_v1` in SharedPreferences, loaded before `runApp`, and
kept separate from IndexedDB Operation, health, Schedule and Reminder records.

Audio keeps the released base levels: Water Drop 0.28; COMMAND / EXIT /
REJECTED 0.34. The shared backend multiplies each base by master and channel
preferences. Mute preserves all slider values and silences active playback.
Settings sliders preview only on release, without ripple or ordinary input
feedback. The latest semantic response replaces older audio; ambient audio
never displaces an active semantic response. Playback stays bounded and
completion, rejection, replacement and disposal clean up listeners.

Brightness defaults to 100%, with no dimming layer. Lower choices down to 35%
add an IgnorePointer overlay without changing layout, viewport or theme.
Ripple and Dashboard Ambient Circuit default ON and remain independent of
ambient audio and wildlife. Reduced Motion SYSTEM follows Flutter's platform
disableAnimations signal; ON forces that existing path; OFF permits normal
motion only when the platform signal is false. Platform accessibility wins.

Complete Backup & Restore includes an optional top-level `deviceSettings`
preference object outside formal record sections. Existing schema versions and
formal record contracts are unchanged. Complete replace-all restore applies
these preferences; older backups without them restore production defaults.
Record merge retains the receiving device's preferences. Invalid and partial
preferences normalize through the same safe defaults and clamps as startup.
DEVICE TRANSFER links to this complete Backup & Restore flow. Formal operation
transfer/synchronization does not carry these device-local preferences.

Browser and widget checks cannot establish iPhone audio or physical-device
acceptance. Real-device acceptance remains a separate step.

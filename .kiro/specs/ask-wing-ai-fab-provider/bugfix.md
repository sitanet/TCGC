# Bugfix Requirements: AskWingAICubit Provider Missing

## Introduction

When users click the "Ask Wing AI" FAB button on the home page, the app crashes with a Provider error: "Could not find the correct Provider<AskWingAICubit> above this AskWingAIChatPage Widget". This occurs because the `AskWingAICubit` is being accessed via `context.read<AskWingAICubit>()` without ever being provided in the widget tree. The fix involves initializing and providing the cubit at an appropriate level in the widget hierarchy (MainScreen) so it's available throughout the app before navigation to the chat page.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the user clicks the Ask Wing AI FAB button on the HomePage THEN the app crashes with the error "Could not find the correct Provider<AskWingAICubit> above this AskWingAIChatPage Widget"

1.2 WHEN HomePage attempts to read the AskWingAICubit using `context.read<AskWingAICubit>()` in the FAB's MaterialPageRoute builder THEN the operation fails because no BlocProvider has supplied the cubit to the widget tree

1.3 WHEN AskWingAIChatPage's initState calls `context.read<AskWingAICubit>()` THEN the widget cannot locate the cubit in its context ancestry, causing a ProviderNotFoundException

### Expected Behavior (Correct)

2.1 WHEN the user clicks the Ask Wing AI FAB button on the HomePage THEN the app successfully navigates to AskWingAIChatPage without errors

2.2 WHEN AskWingAICubit is provided at the MainScreen level using BlocProvider THEN the cubit is available to all descendant widgets including HomePage and its navigation destinations

2.3 WHEN AskWingAIChatPage's initState calls `context.read<AskWingAICubit>()` THEN the cubit is found in the context and successfully initialized

2.4 WHEN HomePage's FAB builder accesses the cubit via `context.read<AskWingAICubit>()` THEN the read operation succeeds because the cubit has been provided higher in the widget tree

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the app initializes and MainScreen builds THEN all other functionality (navigation, audio playback, wallet, etc.) continues to work as before

3.2 WHEN other pages like AudioPage, LiveStreamPage, WalletPage, and TeensPage are displayed THEN they remain unaffected and function normally

3.3 WHEN the user navigates away from the chat page via back button THEN the app returns to the home page with existing state preserved

3.4 WHEN the app transitions between different bottom navigation tabs THEN the behavior remains unchanged and no unintended side effects occur

3.5 WHEN users are offline or not authenticated THEN the app continues to show offline downloads page or authentication flows without attempting to provide the cubit prematurely

@echo off
cd /d "c:\Users\User\Desktop\Development\TCGC"
git add lib\presentation\pages\wallet\transaction_processing_page.dart lib\presentation\pages\wallet\failure_page.dart
git commit -m "fix: Add timeout detection and user-friendly error messages for donations"
git push
echo Done!
pause

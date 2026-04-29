@echo off

set AVD_NAME=Tablet

start "" emulator -avd %AVD_NAME% -no-snapshot-load ^
-qemu ^
-serial COM7

adb wait-for-device
adb root
adb shell "ln -sf /dev/ttyS0 /dev/ttyS8"
adb shell "ls /dev/ttyS*"
adb shell "setenforce 0"
adb shell "getenforce"
pause
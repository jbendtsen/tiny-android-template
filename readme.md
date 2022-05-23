# Tiny Android Template

*For Android projects written in Kotlin and/or Java, using the latest AndroidX libraries*

The purpose of this template is to give people the ability to write Android apps without having to use Android Studio or Gradle.
When I picked up Android dev for the first time, I was struck by how frustratingly slow and janky these tools were to use,
and that they seemed to only run at an acceptable pace on machines designed for gaming.
However, I still wanted to write apps for Android, so I developed this template so I could continue my work without having to use an IDE or external build system.

### Requirements
- Java Development Kit (JDK)
- Kotlin Compiler ***(optional)***
- Android SDK
- 7-Zip
- Bash & Perl (Cygwin/MSYS if on Windows)

### Does Not Require
- Android Studio
- Gradle
- Apache Maven / Ant
- Any external build system

## Getting the Android SDK

At the time of writing, [https://dl.google.com/android/repository/repository2-1.xml] contains a list of links to packages that form the Android SDK.
The only required SDK packages for compilation are `build-tools_<version>-<os>.zip` and `platform_<version>.zip`.
If you wish to run native code with JNI, you'll also need `android-ndk-<version>-<os>.zip`.
For running the app remotely, you'll find `adb` inside `platform-tools_<version>-<os>.zip`.

To download the SDK packages, run `sdk-package-list.py`, which will generate `sdk-package-list.html` with links to all SDK downloads.
Alternatively, you can acquire packages manually by downloading the aforementioned xml file and append each package name to `https://dl.google.com/android/repository/`.

## Installing the Tools

1) Make sure you have 7-Zip, Java Development Kit (a superset of the Java Runtime Environment), Bash & Perl, and optionally the Kotlin compiler installed. These will all need to be accessible from your $PATH variable (see [https://en.wikipedia.org/wiki/PATH_(variable)]). If you're on Windows, you'll need Cygwin/MSYS to make use of Bash and Perl.

2) Copy all files from this repository into a separate folder. In the level above that folder, create another folder called `Sdk`.

3) Download the `build-tools` and `platform` Android SDK packages - see **"Getting the Android SDK"** above for details. Extract the contents of both archives (at the top level) into the `Sdk` folder.

4) Check the variables at the top of the `includes.sh`. Edit them to match the names of the folders that were just extracted.

## Selecting a template

This repository offers three templates: vanilla, JNI and AndroidX. Only the AndroidX template has dependencies.
To select one to start from, rename `src-<template>` to `src` and `res-<template>` to `res`.

## Usage

1) Prepare the Kotlin standard library - *Only necessary for Kotlin projects*
- `./kotlin-pre.sh`
	- This will prepare a copy of the Kotlin standard library for your project in DEX form, which is required for a Kotlin app on Android.

2) Get library packages - *Only necessary if there are dependencies*
- `./get-packages.sh pkg-list.txt`
	- This will retrieve AndroidX library packages from Google's Maven repository. The included `pkg-list.txt` contains the list of packages required for "Hello World".

3) Unpack & merge libraries - *Only necessary if there are dependencies*
- `./export-libs.pl`
	- Combines and compiles library resources while resolving resource name merge conflicts. Essentially, your code and the libraries/packages you use have resources which effectively must share the same namespace. This script is the first step in the merging process.

4) Build libraries - *__REQUIRED__ unless there are no resources or libraries*
- `./link.pl`
	- Links all resources, fixes library resource references and compiles library classes into DEX bytecode. Most of the work for creating the app is done here. The Android VM has an *interesting* method of locating and making use of resources; this script prepares project & library code and resources to match the expected layout/format.

5) Compile native code - *Only necessary for projects that use JNI*
- `./jni-compile.sh`
	- If you plan to use JNI, you'll likely need to modify this script to suit your needs

6) Create APK (you will need a KeyStore file for this. See **"Notes"** for details.)
- `./make.sh`
	- This step basically just assembles the files from previous steps into an APK file, while additionally signing the app.

7) Install and run the app on a real device using ADB
- `./run.sh`
	- There is also a `logs.sh` script which dumps the ADB log to the console.
	- On Linux, if `run.sh` or `logs.sh` fail with `user <user> is not in the plugdev group`:
		- Ensure the plugdev group is created with `groupadd plugdev`
		- Ensure the current user is part of the plugdev group with `sudo usermod -a -G plugdev <user>`
		- Try logging out and logging in again
	- If instead you get the error `missing udev rules? user is in the plugdev group`:
		- Try killing the adb process with `kill -9 $(pidof adb)`
		- Try unplugging and plugging in your device again
		- Try adjusting the charging/USB options on your Android under the "Use USB for" section

If your list of libraries change, go to step 3.

If you create or delete (or possibly rename) any resources, go to step 4.

Otherwise, simply running `make.sh` should be enough to ensure that you have a fresh build.

The `make.sh` script will compile anything that's in the `src` folder.
To compile the Java version, simply rename the `src` folder to something else and rename `src-java` to `src`.

## Notes

**You may need to change some configuration variables found at the top of each script**.
`kotlin-pre.sh` in particular relies on a hard-coded path which is system dependent.
Other examples include KeyStore password, Android SDK location and version, etc.
Most of these variables can be found in `includes.sh`.

If you're getting `attribute <thing> (aka <package>:<thing>) not found` errors in `link.pl`, try adding `<thing>` to `@DELETE_LIST` at the top of `export-libs.pl`.
This will ensure that any attributes that can't be defined without a library you don't have (eg. a support library) are (temporarily) deleted before linking library resources.

As long as your JDK version can target Java 8, this should work. Tested with OpenJDK 13.0.2.

You will need to make sure the `bin` directories for the JDK and for 7-Zip (and the Kotlin compiler if you're using Kotlin) are in the $PATH variable.

In order to build the APK, `apksigner` needs a KeyStore file. This can be generated with `keytool`, which comes with the JDK.
The following command generates a KeyStore file (keystore.jks) which is valid for 10000 days:

`keytool -genkeypair -keystore keystore.jks -keyalg RSA -keysize 2048 -validity 10000`

These scripts use the `d8` tool from the Android SDK (as opposed to `dx`). Thus, your build-tools version must be >= 28.0.1.

To delete the library cache in your project, simply delete the `lib` folder that was created, then run `get-packages.sh` again.

If you're using Linux/OS X/etc. and you're getting a `permission denied`-esque error, try using `chmod +x` on the `.sh` and `.pl` files in this repo.

This template is loosely based off [https://github.com/authmane512/android-project-template]


![HBC Digital logo](https://raw.githubusercontent.com/gilt/Cleanroom/master/Assets/hbc-digital-logo.png)     
![Gilt Tech logo](https://raw.githubusercontent.com/gilt/Cleanroom/master/Assets/gilt-tech-logo.png)

# CleanroomASL Integration Notes

This document describes how to integrate CleanroomASL into your application.

CleanroomASL is designed as a *universal Swift framework* with support for the following platforms within a single binary:

Platform|Latest supported OS|Oldest supported OS
--------|-------------------|-------------------
iPhone/iPad|iOS 10.2|iOS 8.0
Macintosh|macOS 10.12|macOS 10.10
Apple TV|tvOS 10.1|tvOS 9.0
Apple Watch|watchOS 3.1|watchOS 2.0

CleanroomASL uses **Swift 3.0.2** and **requires Xcode 8.2** to compile.

### Options for integration

There are two supported options for integration:

- **[Carthage integration](#carthage-integration)** uses the [Carthage](https://github.com/Carthage/Carthage) dependency manager to add CleanroomASL to your project.

- **[Manual integration](#manual-integration)** involves embedding the `CleanroomASL.xcodeproj` file within your project’s Xcode workspace.

Once properly integrated, you can make use of [the API](https://rawgit.com/gilt/CleanroomASL/master/Documentation/API/index.html) provided by CleanroomASL in any Swift file using the statement:

```swift
import CleanroomASL
```


## Carthage Integration

Carthage is a third-party package dependency manager for Apple platforms. As of this writing, the current supported version of Carthage is 0.18.1.

Installing and using Carthage is beyond the scope of this document. If you do not have Carthage installed but would like to use it, [you can find installation instructions on the project page](https://github.com/Carthage/Carthage#installing-carthage). 

### 1. Add CleanroomASL to Cartfile

Within to your project’s root directory, Carthage-based projects will store a file named "[`Cartfile`](https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md#cartfile)".

To integrate CleanroomASL in your workspace, you would start by adding the following line to the `Cartfile`:

```
github "gilt/CleanroomASL" ~> 2.1.0
```

This specifies that Carthage use the latest version of CleanroomASL that is API-compatible with 2.1, i.e. any 2.1.*x* version.

**Note:** Be sure to check the [latest releases](https://github.com/gilt/CleanroomASL/releases); there may be a newer version than 2.1 that is no longer API-compatible.

### 2. Download CleanroomASL using Carthage

Once added to your `Cartfile`, you can use Carthage to download CleanroomASL to your machine:

```
carthage bootstrap --no-build
```

Normally, Carthage automatically builds framework binaries for all dependencies in the `Cartfile`. By passing the `--no-build` argument to `carthage bootstrap`, Carthage only downloads the dependencies; it doesn't build them. This preserves your option of building the dependencies directly within your own Xcode workspace.

> If you do not wish to have Carthage build dependencies that it has downloaded, you can proceed to the [Manual Integration](#manual-integration) section.

### 3. Build CleanroomASL using Carthage

To have Carthage build (or re-build) CleanroomASL, issue the command:

```
carthage build CleanroomASL
```

You can also use the `--platform` argument to speed up build times by limiting the set of processor architectures that need to be built.

To build for|Supply the argument
------------|-------------------
iPhone/iPad|`--platform ios`
Macintosh|`--platform mac`
Apple TV|`--platform tvos`
Apple Watch|`--platform watchos`


Even though CleanroomASL is designed as a universal framework, during the build process, Carthage splits the framework into separate binaries for each Apple platform.

After a successful build, you will find platform-specific binaries for `CleanroomASL.xcodeproj` in the appropriate Carthage build folder:

The binary for|Is located in
--------------|-------------
iPhone/iPad|`Carthage/Build/iOS`
Macintosh|`Carthage/Build/Mac`
Apple TV|`Carthage/Build/tvOS`
Apple Watch|`Carthage/Build/watchOS`


For further information on integrating Carthage-built frameworks, see the section on "[Adding frameworks to an application](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application)" in the [Carthage documentation](https://github.com/Carthage/Carthage#carthage--).

### 4. Add the necessary framework to your target

Open your project window in Xcode, and press `⌘-1` to display the Project Navigator.

In the lefthand pane, select the icon for your project. It will be the top item in the Project Navigator list.

Next, select the Build Target to which you want to add `CleanroomASL.framework`, and then select the General tab.

Where you add the framework depends on the type of target you're building. If you're building an application, you'll need to add the framework to the **Embedded Binaries** section.

Otherwise, it should go into **Linked Frameworks and Libraries**.


### 5. Attempt to build

Select the appropriate Build Scheme for your Target, and press `⌘-B` to try to build. If all goes well, your integration was successful!


## Manual Integration

Manual integration involves embedding the Xcode project file for CleanroomASL directly within your own Xcode workspace.

Successful manual integration depends on the particulars of your project structure and development workflow.

> **Note:** These instructions assume that you are using an Xcode workspace specifically—and not just a project file—in order to integrate CleanroomASL.

### Integration using Carthage and --no-build

If you use the `--no-build` flag with Carthage to only downloading dependencies—and not build them—you will want to integrate the project file found at:

```
Carthage/Checkouts/CleanroomASL/CleanroomASL.xcodeproj
```

### Other Integrations

If you acquired the CleanroomASL’s source code through some other means, you will need to locate the `CleanroomASL.xcodeproj` project file: .

### 1. Adding the project files

Open your project window in Xcode, and press `⌘-1` to display the Project Navigator.

Then, using Finder, drag each of the following project files into the *top level* of the Project Navigator, below your project (and any pre-existing dependencies):

```
• CleanroomASL.xcodeproj
```

Ensure that, as you add each project file, it is placed at the top level of the workspace. It must be parallel to (a sibling of) your own project, and not embedded in another project or folder.

### 2. Add the necessary framework to your target

In the lefthand pane of Xcode's Project Navigator, select the icon for your project. It will be the top item in the list.

Next, select the Build Target to which you want to add `CleanroomASL.framework`, and then select the General tab.

Where you add the framework depends on the type of target you're building. If you're building an application, you'll need to add the framework to the **Embedded Binaries** section.

Otherwise, it should go into **Linked Frameworks and Libraries**.


### 3. Attempt to build

Select the appropriate Build Scheme for your Target, and press `⌘-B` to try to build. If all goes well, your integration was successful!


## Further Reading

Want to learn more about CleanroomASL? Check out [the README](https://github.com/gilt/CleanroomASL/blob/master/README.md) or [the API documentation](https://rawgit.com/gilt/CleanroomASL/master/Documentation/API/index.html).

**_Happy coding!_**

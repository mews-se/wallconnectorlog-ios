# Contributing

Thanks for looking. WallConnectorLog is a one-person hobby project, so here is what fits, how the
project is put together, and what will save us both some time.

## Scope

WallConnectorLog reads your own [WallConnectorLog
server](https://github.com/mews-se/wallconnectorlog) — the open-source logger that watches a
Tesla Wall Connector Gen 3 around the clock. The app never talks to the charger or to Tesla, and
it never writes to your server.

Anything that needs a Tesla login, sends data to a third party, or tries to control the charger
is out of scope. Not because those are bad ideas — they are just a different app.

## Building

```
brew install xcodegen
xcodegen generate
open WallConnectorLog.xcodeproj
```

The Xcode project is generated from `project.yml` and not committed, so run `xcodegen generate`
again after adding a file or editing that file. A new source file that is not in the generated
project does not fail loudly — it simply is not compiled.

iOS 18 or later, iPhone only.

## Before you open a pull request

Open an issue first for anything bigger than a fix. It saves you writing code that I then have to
turn down for reasons that were only in my head.

Branch from `dev` and open the pull request against it. `main` follows behind and is what the
outside sees: the front page, this file, and the source a release is cut from.

Look at the [open milestones](https://github.com/mews-se/wallconnectorlog-ios/milestones) and the
`planned` label before you start. What is listed there is either being worked on already or
decided, and it is the cheapest way to avoid writing something twice. However, feel free to
comment if you feel that you want to work on something planned. Planned does not automatically
mean me :)

Work lands in `dev` and waits there. Releases gather a body of changes rather than going out one
at a time, so a merged pull request can sit for a while before it reaches the App Store. That is
the plan, not neglect.

There is no test suite. The simulator is the test, so build and click through the screens your
change touches, including the ones that only differ when a value is missing — a charger the
server cannot reach, a session that has not ended yet, a field an older firmware never reports.
Typing demo in the server field gives you a full set of example data to click against.

Keep commits focused. Subject in the imperative, and a body explaining why when the why is not
obvious from the diff.

## Strings

All user-facing text is English only and lives as plain literals in the views — the app carries
no string catalog. Established terms stay put: Wall Connector is Wall Connector.

## Naming

Tesla and Wall Connector are trademarks of Tesla, Inc. Mention them in prose and in compatibility
notices, but keep them out of product and feature names.

## Licence

MIT. By contributing you agree that your work is published under it.

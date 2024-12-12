# Migrating to V2

Most of the public-facing API of Overture has changed with the release of version 2.

StarterPlayerScript and StarterCharacterScript tags have been completely removed, in favour of RunContex. This will likely require significant changes.

```regex
(Get|GetLocal|WaitFor)?(RemoteEvent|RemoteFunction|BindableEvent|BindableFunction)\((".*?")\)
```

```regex
\1("\2", \3)
```

<div align="center">
	<img src="https://github.com/devSparkle/overture-vscode/blob/main/assets/icon-dark.png#gh-light-mode-only"" alt="Cmdr" height="150" />
	<img src="https://github.com/devSparkle/overture-vscode/blob/main/assets/icon.png#gh-dark-mode-only"" alt="Cmdr" height="150" />
	<br/>
</div>

<!--moonwave-hide-before-this-line-->

>**o·ver·ture**  
>*/ˈōvərCHər,ˈōvərˌCHo͝or/*
>
>1. an orchestral piece at the beginning of an opera, suite, play, oratorio, or other extended composition.
>2. an introduction to something more substantial.

Overture is a source management module for Roblox. Overture was created to decomplexify the loading of libraries, streamline OOP classes and bridge the server-client gap!

For more information on usage, head over to the [documentation webpage](https://devsparkle.me/Overture/).


## Getting Started
Head over to the [releases tab](http://github.com/devSparkle/Overture/releases) and download the prepared `.rbxm` file. Insert this file into your game and drag the ModuleScript to `ReplicatedStorage`.

Then, require it in your code like the example below:

```lua
local Overture = require(game:GetService("ReplicatedStorage"):WaitForChild("Overture"))
```

### Wally

Overture is also available through Wally! Include it in your project by adding the following to your `wally.toml`:
```toml
Overture = "devsparkle/overture@^2"
```

## Extension
Development with Rojo can be turbocharged with the [VSCode extension for Overture](https://marketplace.visualstudio.com/items?itemName=devSparkle.overture-vscode), which amongst other features provides typechecking support for modules required through `LoadLibrary`.

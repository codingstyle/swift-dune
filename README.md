# Dune

This repository contains a reinterpretation from Dune game, originally published by Cryo Interactive.
It is written in Swift 5.6 and runs on macOS.

## Installation

You need the original assets from the game to play it.
Create a subfolder `DuneFiles` and place the files in it.

## How to use

The application currently has two modes:
- Editor view: used to view the assets (shortcut: `Cmd` + `E`)
- Game view: for playing the game (shortcut: `Cmd` + `G`)

## Architecture

Code is split between three main sections:
- Editor: asset viewer
- Game: the game logic
- Engine: primitives for parsing original assets, perform world simulation and rendering

Architecture tries to use modern patterns like events and node structure.  

## Thanks

I got inspired by prior reverse-engineering works that amazing people made across the years:
- [Zwomp](https://zwomp.com/tags/dune/)
- [Madmoose](https://github.com/madmoose)
- [OpenRakis initiative](https://github.com/OpenRakis)
- [Bigs](https://www.bigs.fr/dune_old/)
- [hsqLib](https://github.com/jeancallisti/hsqLib)

A Dune Reborn Discord can be joined to discuss various works around the game here:
[Join the Discord](https://discord.gg/vxwSUhwRBr)


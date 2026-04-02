# Tac-Slack: 5 Ninjas in trenchcoat Training Manual
Here are the keys to uncle papi's old hotrod of an operating system.
So you've got the hotrod running, but you're missing a part. Here is how to use Tac-Slack to keep your system on the bleeding edge.

### 1. The Workflow
When you download a piece of software, don't worry about what format it's in. Just run:
`tac-slack filename`

The script will identify the file, build the package, and pause to show you the **Forge Report**.

### 2. Understanding the Forge Report (The Dependency Scanner)
Before installing, Tac-Slack runs a scan. You might see:
- **"All clear":** The package is self-contained. Go for it!
- **"MISSING: libxyz.so.1":** This is a warning. It means the software you are trying to install is looking for a "part" your system doesn't have.

**What to do if you're missing a part:**
1. Don't panic. Slackware is a giant puzzle.
2. Search for the missing library name (e.g., `libxyz`) on the [SlackBuilds.org](https://slackbuilds.org) repository.
3. If it's not there, it might be in the Arch Linux repository. Download that Arch package and run `tac-slack` on it to "raid" the missing library.

### 3. The Install/Hold/Burn Decision
After the scan, you are the pilot:
* **Install:** Bolts the package onto your system immediately.
* **Hold:** Saves the file to your current folder (useful if you're building a collection for another machine).
* **Burn (Remove):** Vaporizes the temporary forge files.

### 4. A Note on "Funny Business"
If you’ve installed a package and it won’t launch, the first thing to do is run the program from the terminal. If it throws a `lib-not-found` error, you know exactly what to go hunting for. 

Remember: You aren't just a user; you're the lead mechanic. Welcome to Slackware.
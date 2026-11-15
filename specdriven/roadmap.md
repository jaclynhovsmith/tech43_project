# Roadmap

**Status.** approved

Built in this order so we have something usable as early as possible.

## 1. Catch fixed-format personal info and hold the prompt — M
**Why.** The core loop: a prompt with an email, phone number, ID number or card number is held back, you see what was found, and you choose to send it anyway or go back and edit. Clean prompts pass straight through. ("Held back… see what was found", "You choose", "Prompts with nothing sensitive go through".)
**Depends on.** none
**Status.** ☑ done

## 2. Catch secrets — S
**Why.** Adds passwords, API keys, access tokens and private keys to the same warning. These are the most costly things to leak. ("Held back… personal info or a secret".)
**Depends on.** #1
**Status.** ☐ not started

## 3. Catch names and street addresses — M
**Why.** Adds the fuzzier personal info. When it's unsure, it warns anyway. ("When it's unsure, it warns anyway".)
**Depends on.** #1
**Status.** ☐ not started

## 4. Quiet the false alarms — S
**Why.** A "don't flag this" list for specific things, like your own name, plus switches to turn whole kinds of checks off. Both are kept on your computer. ("…quickly silence things you know are fine".)
**Depends on.** #1. Most useful after #3, since names cause the most false alarms.
**Status.** ☐ not started

## 5. Publish it — S
**Why.** Package it as a Claude Code plugin with a short README so a stranger can find it, install it and have it working in a couple of minutes. ("A stranger can find it, install it…")
Also, moved from #1: try a real paste in the interactive app and confirm it's checked; the README explains how to turn the plugin off (Claude Code's own message doesn't, if the check can't start).
**Depends on.** #1–#4
**Status.** ☐ not started

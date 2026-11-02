---
name: progress
description: A full status update on the task this conversation is working on, checked against live state. Use when the user types /progress or asks where things stand, what is left, or how close the task is to done.
---

# Progress

Report where the task stands: what is done, what is running, what is left, and how close it is to closed out. Build it from the conversation, including any compacted summary.

## 1. Check live state

Re-check every fact the update will state that can change on its own: PR state and CI, deploys, background jobs and subagents, flags or config you changed, and any production number you quote. Done when each such fact in the update was read in this turn, or is labelled as last seen at a given time.

## 2. Define done

Done is the outcome the user asked for, verified working where it runs. Edge-case follow-ups that will realistically never be hit are not part of done: list them under Parked, or leave them out.

## 3. Write the update

1. **TLDR**: one or two lines, where the task stands and the single next step.
2. **How close**: a rough percentage or "N of M milestones", against the definition of done.
3. **Done**: `- [x]` items, most important first, each with its evidence (PR, commit, check, query).
4. **In progress**: what is running now and what it waits on.
5. **To do**: the remaining critical-path steps, in order, marking the ones that need the user.
6. **Needs you**: each action or decision only the user can take, as the exact command or a one-line question. Write "Nothing" when there is none.
7. **Parked**: real, non-blocking follow-ups, one line each.

One line per item. Give the source of any number that is not obvious, and label anything unverified as a hypothesis. Where a choice is open, lead with the option you recommend and why.

Created by the team behind [Cavuno](https://cavuno.com) and [Himalayas](https://himalayas.app).

---
name: expert-prompt
description: Find the top practitioners for a goal, then write the prompt in the register they would use, so the answer comes back at their depth.
disable-model-invocation: true
---

Models complete in the register they are prompted in. A mid prompt gets a mid answer; a prompt written the way a field's best practitioner would write it gets an answer at that depth. This skill builds that prompt in two passes: find the **leaders**, then write in their **register**.

The input is the user's goal, in whatever words they used. Anything after the skill name is the goal; if there is none, ask for it in one question.

## 1. Pin the goal

Restate the goal as the decision or understanding the user actually wants, plus the field it lives in (it may span two, e.g. growth and AI infrastructure). Keep the user's own situation to the facts the prompt needs; the prompt is about the field's model of the world, with the user's case as the example.

Done when: one sentence names the decision and the field(s). Ask one question only if the field is genuinely ambiguous.

## 2. Find the leaders

Pick 3 to 5 people who both **did the work** at a serious scale and **changed how the field thinks** (frameworks, essays, books others argue from). Prefer the unusual, sharp voices over the merely famous. Use web search to confirm each person's current role, since your training data may be stale.

For each leader, record:
- **Credential:** what they built or ran, in one line.
- **Signature ideas:** 3 or more named concepts, frameworks or essays that are theirs or that they argue from.
- **Stance:** a consensus take they'd reject, and why.

Done when: every leader has a verified credential, at least 3 real signature ideas, and a stance. Drop anyone you can't fill in honestly.

## 3. Extract the register

From the leaders, build the **lexicon** the prompt will speak in:
- Terms of art and named frameworks, used precisely (the essay or book each comes from).
- The questions they'd ask that a novice wouldn't, such as decomposing into mechanisms, base rates from history, and which node of a loop breaks.
- Their standard of evidence: what they'd accept as proof, and what they'd dismiss as anecdote.
- The consensus takes they'd push back on, which become the prompt's opening tension.

Done when: the lexicon has at least 10 precise terms and at least 3 consensus takes to argue against.

## 4. Write the prompt

Write it in first person, as one of these practitioners would write it for their own use. The depth comes from the wording itself; avoid "act as X" role-play, which gives you costume rather than depth. Structure:

1. **Context:** a few lines on the user's situation, framed as the case study.
2. **The real question,** stated sharply.
3. **Position against consensus:** name the takes that are wrong or shallow and the source of the better argument.
4. **Numbered workstreams,** each built on a named framework or mechanism from the lexicon, each asking for decomposition, not opinion.
5. **Standards:** argue at the level of mechanism; cite primary sources and label the rest as hypotheses; steelman the bear case with historical analogues; disagree with the framing where it's wrong.
6. **Close** with 4 to 6 dated, falsifiable predictions that would prove the answer wrong, and ask for a TLDR first.

Done when: every workstream names at least one real framework or mechanism, every term is used correctly, and a leader reading it would recognise it as written by a peer.

## Output

- The leaders: one line each (name, credential, why they're here).
- The prompt, in a single fenced code block, ready to paste.
- One line naming the reference points the prompt leans on, so the user knows where the depth comes from.

Use no em dashes in the prompt or the output.

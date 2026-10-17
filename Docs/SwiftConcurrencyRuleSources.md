# Swift Concurrency Rule Sources

ARCA's Swift concurrency rules are derived from
[AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill)
at commit `d5770817d2622e1585b1f7eaebc791a9cb0959c8`.

The structured ARCA rule definitions and single-file evidence boundaries are
ARCA-specific. Upstream examples are reused unchanged when they isolate one
rule and remain compact. Custom examples are used when broader upstream
examples would introduce another violation or require context outside the
analysed file.

| ARCA rule | Example provenance |
| --- | --- |
| 001 | Custom unsafe example; exact actor example from [actors.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/actors.md#L29-L36) |
| 002 | ARCA-specific examples; task ownership informed by [tasks.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/tasks.md#L62-L82) |
| 003 | Exact unsafe and actor examples from [sendable.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/sendable.md#L328-L356) |
| 004 | Custom unsafe example; exact global-actor example from [sendable.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/sendable.md#L432-L451) |
| 005 | Exact reentrancy examples from [actors.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/actors.md#L376-L411) |
| 006 | Source-derived region-transfer examples from [sendable.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/sendable.md#L360-L417) |
| 007 | Custom misuse example; exact independent-work example from [tasks.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/tasks.md#L412-L430) |
| 008 | Custom cancellation misuse; exact cancellation-aware loop from [memory-management.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/memory-management.md#L522-L541) |
| 009 | Custom misuse example; exact error-propagation example from [tasks.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/tasks.md#L255-L272) |
| 010 | Custom blocking example; exact suspending alternative from [tasks.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/tasks.md#L486-L500) |
| 011 | Exact task-cycle examples from [memory-management.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/memory-management.md#L66-L109) |
| 012 | Exact lifecycle examples from [async-sequences.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/async-sequences.md#L258-L272) and [finish examples](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/async-sequences.md#L653-L667) |
| 013 | Exact single-stream consumer example from [async-sequences.md](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill/blob/d5770817d2622e1585b1f7eaebc791a9cb0959c8/skills/swift-concurrency/references/async-sequences.md#L444-L473) |

The upstream license is reproduced in `THIRD_PARTY_NOTICES.md`.

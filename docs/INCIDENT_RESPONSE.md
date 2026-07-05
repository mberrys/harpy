# Incident response and release discipline (educational)

Harpy is an **educational** blockchain tutorial — not production infrastructure. This playbook defines **minimum process** for validation bugs, bad releases, and chain-state recovery, adapted from production-readiness research ([MIC-34](https://linear.app/mbx2/issue/MIC-34)).

**Out of scope:** 24/7 on-call, formal CVE program, mainnet upgrade committees.

## Roles (tutorial scale)

| Role | Responsibility |
|------|----------------|
| **Maintainer / release manager** | Tags releases, merges PRs, owns rollback decision |
| **Reporter** | Anyone who finds a validation, consensus, or API security bug |
| **Reviewer** | Independent pass on crypto/consensus changes (see `AGENTS.md` AI gates) |

## Release discipline

1. **Versioning** — semver in `Harpy::VERSION`; breaking chain format bumps minor/major and is called out in PR body.
2. **Changelog** — each release PR lists breaking changes (e.g. `chain.json` format, API route removal).
3. **Pre-merge checks** — `crystal spec`, `crystal tool format --check`, independent review for auth/crypto/consensus paths.
4. **Coordinated upgrades** — when `Block` hash preimage or transaction schema changes, operators **delete `data/chain.json`** and regenesis; document in PR and `DEMO.md`.

## Vulnerability and bug reporting

| Channel | Use |
|---------|-----|
| **GitHub Security Advisories** (preferred for exploitable issues) | Private disclosure for auth bypass, signature forgery, consensus split |
| **GitHub Issues** | Non-sensitive validation bugs, doc errors, test gaps |

**Include:** Harpy version/commit, reproduction steps, expected vs actual `Chain#valid?` / mempool behavior, minimal `chain.json` or curl sequence if applicable.

**Do not** file public issues with live `HARPY_API_KEY` values or private keys.

## Severity guide (educational)

| Severity | Example | Response |
|----------|---------|----------|
| **Critical** | Remote unauthorized spend, consensus split on default config | Fix before next release; advisory if ever deployed beyond localhost |
| **High** | Mempool double-spend bypass, fork-choice inversion | Fix + regression spec in same PR |
| **Medium** | DoS on `POST /mine` without rate limit bypass | Fix or document mitigation |
| **Low** | Doc drift, CLI message clarity | Normal issue queue |

## Rollback procedure (bad chain state)

1. **Stop** the Kemal process.
2. **Verify** backup or last known-good file: `crystal run src/harpy.cr -- verify-chain --path data/chain.json`
3. If invalid:
   - Restore from backup **or**
   - Delete `data/chain.json` and restart (regenesis at `HARPY_DIFFICULTY`)
4. **Replay** UTXO expectations with `crystal spec` security specs if consensus code changed.
5. **Post-mortem** (template below) for High/Critical.

## Post-mortem template

```markdown
## Summary
One paragraph: what broke.

## Impact
Who could be affected (tutorial operators, tests, etc.).

## Timeline
Discovery → fix → release.

## Root cause
Code path and missing invariant/test.

## Corrective actions
- [ ] Regression spec
- [ ] Doc/threat-model update
- [ ] AGENTS.md gate if AI-assisted

## Lessons
What we change in process.
```

## Related documents

- [THREAT_MODEL.md](./THREAT_MODEL.md) — threat catalog and deployment guidance
- [AGENTS.md](../AGENTS.md) — AI-assisted development security gates
- [DEMO.md](./DEMO.md) — operator runbook

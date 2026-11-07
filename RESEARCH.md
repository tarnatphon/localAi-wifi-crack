# Research: what actually works for "local AI Wi-Fi cracking"

Compiled 2026-11-07. Every number below is sourced; see [Sources](#sources).
Scope: WPA2/WPA3-Personal, own-network auditing. This is a research summary, not a how-to
for other people's networks.

---

## 1. Verdict up front

| Claim | Verdict |
|---|---|
| You can crack WPA2-PSK offline from a captured handshake/PMKID | **True**, and it is cheap |
| An LLM/AI can *break* the cryptography | **False.** No model shortcuts PBKDF2 |
| AI helps at all | **True but modest** — 2–4× better candidate ordering, i.e. more cracks per guess budget |
| AI helps on your actual target (home Wi-Fi) | **Barely.** 44% of real passwords are phone numbers; a 3-second mask attack beats any model |
| WPA3-SAE is crackable | **False.** No offline attack exists at any hash rate |
| A "local AI Wi-Fi cracker" is a good project on a Mac | **Partly** — the interesting half needs no hardware at all (see §7) |

The single most important finding: **the winning attack is not AI, it is target-shaped
candidate generation.** CyberArk cracked 70% of 5,000 Tel Aviv networks; 44% fell to a
phone-number mask, 18% to `rockyou.txt`. An LLM would have gotten credit for that 44% while
actually adding nothing.

---

## 2. What's on GitHub

### 2.1 Frameworks and capture tools

| Repo | ★ | Lang | Last push | What it is | Verdict |
|---|---|---|---|---|---|
| `bettercap/bettercap` | 20.2k | Go | 2026-11 | Swiss-army 802.11/BLE/CAN recon & MITM | **Overkill** for one AP; excellent for recon |
| `evilsocket/pwnagotchi` | 9.2k | Python | 2026-08 | Pi + bettercap, RL-tuned capture | **Interesting** — the honest "AI in Wi-Fi" case |
| `derv82/wifite2` | 8.2k | Python | 2026-08 | Automates scan → capture → crack | **Use** as reference for orchestration |
| `v1s1t0r1sh3r3/airgeddon` | 8.1k | Bash | 2026-11 | Menu-driven attack suite, evil-twin etc. | Good, Linux-only, huge surface |
| `aircrack-ng/aircrack-ng` | 7.9k | C | 2026-10 | The canonical suite | **Legacy path**, see §2.2 |
| `martin-olivier/airgorah` | 5.1k | Rust/GTK4 | 2026-11 | Modern GUI auditor, polkit agent | **Best-in-class UX** if you have Linux |
| `ZerBea/hcxtools` | 2.5k | C | 2026-10 | pcapng → hc22000 converter + candidate helpers | **Essential** |
| `ZerBea/hcxdumptool` | 2.2k | C | 2026-10 | Modern capture (PMKID, clientless) | **Essential** |
| `hash3liZer/WiFiBroot` | 1.1k | Python | 2021-01 | Handshake+PMKID capture/crack | **Dead** — abandonware |
| `brannondorsey/wifi-cracking` | 12.7k | — | 2024-12 | Tutorial, airodump → aircrack/hashcat | **Read it**, it's a doc not a tool |
| `wlmosv-png/wpaforge` | 161 | Java | 2026-11 | On-phone candidate generation from SSID/vendor/house-number/DOB/phone, **one real association attempt per candidate**, verdict per candidate | **Closest to your idea**, see §5 |
| `derv82/wifite` (v1) | 3.7k | Python | 2022-09 | Superseded by wifite2 | Ignore |

### 2.2 The one architectural decision that matters

`aircrack-ng`-style tooling is the tutorial-standard path, but the modern chain is:

```
hcxdumptool  →  hcxpcapngtool  →  hcxhashtool  →  hashcat -m 22000
 (capture)      (convert)          (filter)        (crack)
```

Reasons: `hashcat -m 22000` is ~30–60% faster than the legacy `-m 2500`; `hcxdumptool`
grabs **PMKIDs clientlessly** (no waiting for a device to connect, no deauth); `hcxtools`
already ships two things people rebuild badly:

- `hcxeiutool` — derive candidate wordlists from the ESSID itself
- `hcxpsktool` — weak-PSK candidates from an existing hc22000 file

**So "AI that generates candidates from the SSID" is partly a solved problem already**,
in C, in a tool nobody has to train. Any AI layer has to beat those heuristics to be worth its complexity.

### 2.3 The "AI" side

| Repo / work | ★ | What it shows | Verdict |
|---|---|---|---|
| `brannondorsey/PassGAN` | 2.0k | 2017 GAN over password leaks; +51–73% matches when *combined* with hashcat | **Historically important, practically weak** |
| `d4ichi/PassGAN` | 152 | PassGAN ported to TF2/3.12 with pretrained model | Runnable, but see §3 |
| `PadishahIII/RFGuess` | 33 | ML social-engineering dictionary from PII | Closest to real value |
| `timbo05sec/autocrack` | 128 | hashcat wrapper / automation | Useful plumbing pattern |
| `stealthsploit/Hashcatalyst` | 33 | attack-chain automation + wordlist enhancement | Same |

**No popular repo does "LLM + Wi-Fi" well.** That gap is real. It is also small — see §4.

---

## 3. What the research actually says about AI password guessing

Numbers are guess-success-rate at a fixed guess budget (higher = better), from the 2026
PassGPT+ evaluation, plus the original PassGAN results:

| Guesses | PassGAN | PassGPT | hashcat rules | PassGPT+ |
|---|---|---|---|---|
| 10⁶ | 0.38% | 0.50% | **0.69%** | **0.78%** |
| 10⁷ | 2.04% | 4.25% | 4.65% | **5.66%** |
| 10⁸ | 6.73% | 19.37% | 6.73% | **22.53%** |

Reading it honestly:

1. **At small budgets, hand-written hashcat rules beat GANs.** PassGAN *below* hashcat until ~10⁸ guesses.
2. **Modern LLM-based generators win at scale** — 22.5% vs 6.7%, roughly 3.3× per guess. Real, measurable.
3. **PassGAN alone is not worth building in 2026.** It loses to hashcat rules and to plain LLMs.
4. A separate 2026 study got cracking from **2.02% → 8.48%** by prompting a *local Qwen3-8B* (or Gemini Flash) with PII + old passwords. That is the strongest practical result, and it needs **no training** — just good prompts.

**Ceiling:** these are gains in *ordering candidates for human-chosen passwords*. They do
nothing at all for a random password, and nothing at all against WPA3.

---

## 4. Why this barely applies to Wi-Fi specifically

Three hard constraints that generic password research glosses over:

**(a) No partial feedback.** PBKDF2 + MIC is all-or-nothing. There is no gradient, no
score, no "close". Reinforcement learning cannot hill-climb a boolean. This is why
`pwnagotchi`'s RL is about *capture strategy* (when to deauth, which channel to hop), not
about guessing passwords. Anyone claiming an RL agent that "learns the password" is wrong.

**(b) The password distribution is dominated by one pattern.** In the 5,000-network study:
44% mobile numbers, 18% `rockyou.txt`, remainder simple numeric/alpha combinations. For a
phone-number population, a mask is optimal and costs seconds:

| Attack | Space | Time @ 2.6 MH/s (RTX 4090) |
|---|---|---|
| Thai mobile `0?d?d?d?d?d?d?d?d?d` | 10⁹ | **~6.4 min** |
| 8 digits | 10⁸ | **38 s** |
| `rockyou.txt` (14.3M) | 1.4×10⁷ | **5.5 s** |
| 8 lowercase | 2.1×10¹¹ | 22 h |
| 8 alphanumeric | 2.2×10¹⁴ | 2.6 years |
| 12 random printable | 5.4×10²³ | ~6.6 billion years |

**(c) Real GPUs are faster than folklore.** Correcting my own earlier estimate of
~1 MH/s: measured mode-22000 rates are **~2,500–2,660 kH/s on an RTX 4090** and
**~3,800 kH/s on an RTX 5090** — roughly 2.6–3.8 MH/s. Doesn't change any conclusion,
but the honest number matters.

**Net:** for Wi-Fi, AI's realistic contribution is *generating the 100k candidates that a
6-minute mask run would otherwise automate*, plus leetspeak/habit mutations and
PII-derived guesses. It shifts a network from "cracked in 6 minutes" to "cracked in 90
seconds" — nice, not transformative. Against a random 16-char password it never finishes.

---

## 5. `wpaforge` is the most interesting find

The one project that matches your mental model, and it makes a smart architectural choice:

- generates candidates from SSID, vendor, house number, name, birthday, phone number
- instead of capturing a handshake, it **makes one real association attempt per candidate**
  via Android's `cmd wifi` (root), and reports success / wrong / uncertain per attempt
- never needs monitor mode or a special adapter
- explicitly self-scoped: own networks only, local-only, no upload

Trade-off: ~1–5 s per candidate → ~12–60 candidates/minute. Fine for a 200-candidate
targeted list, hopeless for `rockyou`. But it proves the "no hardware" path works, and it
is the design I'd borrow for a Mac-native tool (via `networksetup`/`wdutil`, or better, by
skipping the online step entirely — see §7).

---

## 6. YouTube and the tutorial ecosystem — what to ignore

I can't watch videos, so judge this as a characterization of the genre, not a review of
specific channels. Recurring patterns:

**Outdated or wrong (most of it):**
- `aircrack-ng` only, `-m 2500`, WEP-era commands, Kali 2019 screenshots.
- "Capture the handshake without a client connected" — confused with PMKID; the two are different.
- "Hack any Wi-Fi in 2 minutes" / "Wi-Fi password hacker app" — either fake, a repackaged
  `aircrack-ng` GUI, or a Telegram/APK scam. Real risk of malware, zero functionality.
- Anything claiming an app on a stock phone cracks WPA2. It cannot; stock Android/iOS
  cannot enter monitor mode.
- "AI cracks any Wi-Fi password" — see §3, §4.

**Genuinely worth the time:**
- `hcxdumptool` + `hcxpcapngtool` + `hashcat -m 22000` walkthroughs (current workflow).
- hashcat mask/rule optimization talks (atom/Steube, Chick3nman) — this is where the real
  speed lives.
- Defensive content: how to pick a passphrase, WPA3 migration, why WPS must be off.

Rule of thumb: if a video doesn't mention a **specific adapter with monitor-mode support**,
it is not doing 802.11 capture, whatever the title says.

---

## 7. Your actual constraint: this is a Mac

This is the finding that should drive the design. **macOS cannot do 802.11 monitor mode or
packet injection — on any Mac, Intel or Apple Silicon, with any adapter.** Third-party
drivers (ALFA et al.) expose client connectivity only. `airport` was removed in Sonoma
14.4; the built-in card can sniff a single channel via Wireless Diagnostics, with no
injection and no channel hopping.

So the classic pipeline needs one of:

| Option | Cost | Reality |
|---|---|---|
| Kali ARM in UTM/Parallels + USB adapter passthrough | $50 adapter | Works; USB passthrough on Apple Silicon is the fiddly part |
| Raspberry Pi Zero 2 W + `hcxdumptool`, headless | ~$20 | Cleanest, most reliable, run it and walk away |
| Cloud/remote Linux box | varies | Capture still needs to be *physically* near the AP |
| **No capture at all** | **$0** | **See below — this is the good one** |

### The insight

You own the network, so you already know the password. And **PMKID is a pure function of
(SSID, password, AP MAC, client MAC)** — verified here against the IEEE 802.11i Annex H.4
test vector (`SSID="IEEE"`, `password="password"` → `PMK=f42c6fc5…a12e`, exact match):

```
WPA*01*3e07270d0746b999db1bec32482841f1*020000000001*020000000002*49454545***
```

That is a syntactically valid `hc22000` line, generated in 20 lines of Python, **with no
adapter, no monitor mode, no Linux, no capture.** Feed it to hashcat and it behaves exactly
like a real one. You can therefore measure crackability of your own network with 100%
fidelity and zero hardware.

---

## 8. Recommended solution

**Build a Mac-native WPA2 crackability auditor, hardware-free. Skip capture entirely.**

### Phase 1 — the useful 80% (no hardware, runs today)

1. **`hashgen`** — SSID + real passphrase → PMK → PMKID → `hc22000` line (already verified, ~20 lines).
2. **Attack tiers**, run in escalating order, recording *guesses-to-crack* and wall time:
   - `rockyou.txt` (14.3M, 5.5 s)
   - Thai/regional numeric masks (phone, DOB, house number, 8-digit) — the 44% bucket
   - `hcxpsktool` + SSID-derived heuristics (`hcxeiutool` logic, not the binary)
   - `best64`/`dive` rules over a PII-seeded base list
   - **LLM tier**: local Ollama model prompted with SSID, owner name, city, phone prefix,
     leetspeak/habit instructions → deduped, ranked candidate list. This is the actual "AI" contribution:
     a *candidate generator*, not a cracker.
3. **Score + report** — "cracked in 1,400 guesses / 0.6 s" → grade, plus why, plus
   concrete fix ("add 4 random chars: 6 min → 4,000 years").
4. **Router config checks** — WPA2 vs WPA3, WPS enabled, transition mode.

Phase 1 gives you real numbers for the exact question you asked, on the machine you have,
and it measures the AI-vs-baseline delta honestly (same harness, same hash, N guesses).

### Phase 2 — only if you want real-world validation

Add capture for *other* devices/networks you own, on Linux (Pi Zero 2 W or UTM):
`hcxdumptool → hcxpcapngtool →` same Phase-1 attacker stack. Same report, real handshake
instead of synthesized PMKID. This is the part that requires an adapter, and it is the
less interesting half.

### Phase 3 — what makes it "AI" rather than "a script with an API call"

- Candidate **ranking** learned from your own crack history (which families hit, per SSID pattern).
- Prompt-evolved generators (the 2.02% → 8.48% result came from *evolving prompts*, not bigger models).
- A local model only — nothing leaves the machine.

### What I would refuse to build

Wardriving/auto-target acquisition, mass hash collection, evil-twin credential phishing,
default-password lookup tables for other people's ISP routers. Those convert an auditing
tool into an attack tool, and under Thailand's Computer Crime Act §5–7 (and CFAA/CMA
equivalents) unauthorized access is criminal regardless of intent.

---

## 9. Bottom line

- **Do not** build "AI that cracks Wi-Fi". The AI does not crack anything; PBKDF2 does the
  work and AI only reorders guesses, worth ~2–4× at large budgets.
- **Do** build the auditor: synthesized PMKID → tiered attack → crackability score. It is
  hardware-free, Mac-native, legally clean, and it answers the real question.
- **The measurable win over an existing tool** is precise: a harness that reports
  guesses-to-crack for `rockyou` vs masks vs LLM candidates on *your* SSID. Nobody has
  published that comparison for Wi-Fi, and it's the only way to know if the "AI" part earns its keep.
- If the answer comes back "cracked in 900 guesses", the correct output is not a better
  cracker — it's a better password.

---

## Sources

- CyberArk, *Cracking WiFi at Scale with One Simple Trick* (5,000 networks, 70% cracked, 44% phone numbers) — cyberark.com
- PassGPT+, *Leveraging Linguistic Priors for Password Modeling* (2026), 10⁶–10⁸ guess table — arxiv.org/html/2609.39880
- PassGAN, Hitaj et al. (2017), +51–73% combined with hashcat — arxiv.org/abs/1709.00440
- LLM password auditing with local Qwen3-8B / Gemini Flash, 2.02% → 8.48% — 2026 study
- hashcat forum benchmarks, mode 22000: RTX 4090 ≈ 2,529–2,656 kH/s; RTX 5090 ≈ 3,800 kH/s
- ALFA/macOS compatibility: no monitor mode or injection on any Mac; Kali VM + USB passthrough required; `airport` removed in Sonoma 14.4
- WPA3/SAE: no offline attack; ~10% of authentications use WPA3 (HPE-Juniper telemetry 2026)
- GitHub figures via GitHub search API, retrieved 2026-11-07

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

## 10. What world-class practitioners actually do

Reconstructed from published work (Vanhoef, Steube, Hoorvitch), the OSWP/PEN-210 body of
practice, and how commercial red teams scope wireless work. The pattern is consistent and
it is **not** "build a better cracker".

### 10.1 They attack in ROI order, and the password is usually last

| Tier | Technique | Time | Why it wins |
|---|---|---|---|
| 1. Config | **WPS Pixie Dust** (`reaver -K` / `pixiewps`) | **2–60 s** on ~30–40% of WPS-enabled APs | Offline PIN recovery from one M1–M3 exchange; defeats lockouts; bypasses the WPA2 password entirely |
| 1. Config | default / ISP-derived credentials, exposed admin panel | minutes | The password is guessable *by lookup*, not by compute |
| 2. Credential | PMKID → targeted candidates | minutes–hours | The CyberArk path; needs a shaped list, not a big one |
| 3. Identity | **Enterprise: PEAP relay** (`hostapd-mana` + `wpa_sycophant`) | minutes | Authenticates **without ever cracking the password** |
| 3. Identity | GTC downgrade / evil twin + captive portal | minutes | Harvests cleartext or MSCHAPv2 from humans |
| 4. Post-auth | client isolation, VLAN/segmentation, guest→LAN pivot | — | Where the actual damage is; the PSK was never the objective |

The lesson: **every tier above "brute force the PSK" is faster and more reliable than
brute-forcing the PSK.** A professional never spends GPU-days on a PSK if WPS answers in 30
seconds, and never cracks a credential that can be relayed instead.

### 10.2 Their published breakthroughs were subtractive, not additive

- **Vanhoef (Dragonblood)** — found protocol-level flaws in SAE; did not add compute.
- **Steube (PMKID)** — removed the need for a client and a handshake; one frame.
- **Hoorvitch (CyberArk)** — removed the need for clever guessing; 44% were phone numbers.

Each advanced the field by **deleting work**. Nobody advanced it by making the guesser
smarter. That is the strongest available signal about where to spend effort.

### 10.3 They decide before they build

A world-class practitioner asks, in this order:

1. **What decision does this support?** ("Should I rotate this password?" — not "can I crack it?")
2. **What is the cheapest test that changes that decision?** Often: read the router config.
3. **What is already proven?** They compose `hashcat`/`hcxtools`/`reaver` rather than reimplement.
4. **How will I know it worked?** Metric defined first, evidence timestamped and reproducible.
5. **What is the residual risk after remediation?** Re-test, then monitor (WIDS/rogue-AP detection).

They also write the **report** as the deliverable: finding → severity/CVSS → business impact
→ remediation → verification step. "I cracked it" is an anecdote; a finding table is a product.

### 10.4 What that means for this repo

- The **auditor in §8 is the right shape**, but incomplete: it scores a password and ignores
  WPS, PMKID exposure, transition mode, client isolation, and firmware — the things that
  actually break networks. A config audit is higher-ROI than any cracking tier.
- **Keep the LLM tier**, but position it as candidate *generation*, and only ship it if the
  harness proves it beats masks + rules on your SSID. Otherwise it is decoration.
- **Add a monitoring angle** (rogue AP / deauth detection) if this is ever used on a network
  you are responsible for. Detection is what enterprises actually buy.
- **Do not add capture** until a config audit says the password is the weakest link. It
  usually is not.

### 10.5 The one-sentence version

Elite practice here is **subtractive**: find the shortest path to the objective (WPS, relay,
lookup), measure before building, and ship a remediation — the cracker is the least
interesting component, which is exactly why "AI wifi crack" is the wrong product name.

---

## 11. The hotspot — and why it changes the experimental design

A phone hotspot is the best test target available here, but **not** for the reason it first
appears. It is not a stand-in for a router; it is a **controlled lab**, because you own both
variables: the SSID *and* the password.

### 11.1 What a hotspot does and does not have

| Property | iPhone Personal Hotspot | Android hotspot |
|---|---|---|
| Security | WPA2-PSK | WPA2/WPA3 (varies by OEM); some OEMs ship **Open** |
| Password rules | 8–63 ASCII, min 8 enforced | 8+, OEM defaults often 8 random alnum |
| Default password | **three words + 2–4 digits** (iOS 16+), rarely changed | 8 random alphanumeric, often weak |
| WPS | **No** | **No** |
| PMKID | Not guaranteed — clientless capture depends on the AP supporting PMKID in its assoc response | Same |
| SSID | Your device name, i.e. **your real name** | Usually device/model name |

Two consequences for the plan:

1. **Half the attack tiers evaporate.** No WPS (so no 2–60 s Pixie Dust win), and PMKID is
   unreliable on phones. §10's cheapest tier does not apply to a hotspot.
2. **The SSID leaks PII.** "Ekkaphon's iPhone" hands the attacker a first name, a language,
   and probably a transliteration habit. This is precisely the case where LLM candidate
   generation beats both `rockyou` and masks — and it is therefore the **only** scenario in
   this project where the AI tier can prove itself.

### 11.2 The controlled experiment nobody publishes

Because you can *set* the hotspot password, you can run a dose–response sweep instead of one
anecdote. Same SSID, same harness, same hash path — only the password class changes:

| # | Password class | Example | Expected winner | Rough cost @ 2.6 MH/s |
|---|---|---|---|---|
| 1 | 10-digit mobile | `0812345678` | Thai mask | ~6 min |
| 2 | Name + year | `Ekkaphon2024` | **LLM / PII tier** | seconds, if it's generated at all |
| 3 | Leet + name + year | `3kk4phon@2024` | rules + LLM | minutes (rules), seconds (LLM) |
| 4 | iOS default 3 words + digits | `peachbroommap42` | **nothing** | ≈10¹⁴ — out of reach |
| 5 | 16 random | `vT7#qLm2...` | **nothing** | ~10²² — never |

Rows 2–3 are the whole argument for the AI tier; rows 4–5 are the argument that it is not
magic; rows 1 and 4 together show that **the default is stronger than what people type**.
That table, measured on your own hardware, is a more honest and more publishable result than
another "I cracked my own Wi-Fi" post.

### 11.3 The catch: you still cannot capture it on a Mac

Setting the password does not create a monitor-mode interface. On macOS you still cannot see
the handshake, so the hotspot gets tested through **synthesized hashes** (§7) — which is
exactly right, because you know the ground truth and can validate every "crack" instantly
with zero false-positive risk. Real capture of a hotspot is a Pi Zero 2 W job, and even then
PMKID may simply not answer.

### 11.4 Revised roles

| Target | Role | Why |
|---|---|---|
| **Hotspot** | controlled crackability lab | You own SSID + password → repeatable, ground-truthed, AI-verdict-grade |
| **Home router** | config audit | WPS, PMKID exposure, WPA3/transition, client isolation — the high-ROI findings |
| Pi Zero 2 W (§7) | real-world validation | Only if you need to prove it works against a live handshake |

So the two lab targets are **not** redundant: the hotspot answers "is the AI tier real?", the
router answers "what is actually broken?". Neither needs a monitor-mode adapter.

---

## 12. Platform matrix: can it *run* the audit, and can it *be* attacked?

These are two different questions and the answers are nearly inverse. "Crack a Mac / PC /
iPhone / Android / iPad" can mean either, so both are below.

### 12.1 Can the platform run the audit?

| Platform | Offline cracking (hashcat) | 802.11 capture (monitor/inject) | Verdict |
|---|---|---|---|
| **Windows PC** | **Yes — best case.** Full CUDA/ROCm speed: RTX 4090 ≈ 2,600 kH/s | No. Needs Kali (boot/VM) or a Pi | **The GPU machine** |
| **macOS** (any Mac) | Yes, Metal/OpenCL, but slow — **M2 Max ≈ 275 kH/s, M2 Pro ≈ 126 kH/s, M5 ≈ 135 kH/s, M1 Ultra ≈ 285 kH/s** | **No.** No monitor mode, no injection, any adapter | Fine for wordlists, ~10× too slow for masks |
| **Android** (phone/tablet) | Technically, via NetHunter chroot; impractical | Only with **full NetHunter: unlocked bootloader + root + custom kernel + USB OTG adapter**. Internal chips: QCACLD-2.0 yes, QCACLD-3.0 monitor-only, MediaTek **no**. Nexmon only on ancient Broadcom (Nexus 5 class) | Portable capture rig, not a cracker |
| **iPhone / iPad** | **No.** No hashcat, no raw sockets, no custom kernel, no realistic modern jailbreak | **No.** Not even with an adapter | **Target only** |

Concrete consequence: a Mac is **~10–20× slower than one RTX 4090** on WPA hashes. That is
not fatal — `rockyou` is 52 s at 275 kH/s — but a 10-digit mobile mask goes from 6 minutes to
~1 hour, and anything beyond 10⁹ guesses moves from "hours" to "next month". If the PC has a
discrete NVIDIA card, run the heavy tiers there and the report on the Mac.

### 12.2 Can the platform be attacked?

Split by *what* is being attacked, because the economics differ by orders of magnitude:

| Target | Attack | Reality |
|---|---|---|
| Hotspot on iPhone / iPad / Android tab | The **Wi-Fi layer** | **Yes, and device-agnostic.** A hotspot is just WPA2-PSK; §11 applies identically. iPhone vs iPad vs Tab changes nothing cryptographically |
| Saved Wi-Fi passwords on macOS | Keychain | Requires the **login password**. No login password → no Keychain |
| Saved Wi-Fi passwords on Windows | `netsh wlan` profile store | Requires being logged in as that user, or admin + offline SAM work |
| Saved Wi-Fi passwords on iOS/iPadOS | — | Requires an **unlocked** device. No unlock → no list |
| Saved Wi-Fi passwords on Android | — | Root (legacy) or a system-privileged app |
| **Device unlock / full data extraction** | Secure Enclave (iOS/iPadOS), FileVault (macOS), TPM/BitLocker (Windows), FBE + Titan M (Android) | **Different discipline entirely** — hardware forensics, not Wi-Fi. iPhone/iPad with a modern SoC is effectively closed to DIY; Android varies wildly by vendor and bootloader state |

Two honest conclusions:

1. **"Cracking the device" is not an extension of this project.** It is a different field with
   different economics, and for iPhone/iPad the answer is "no, not by you". I'll document the
   defensive side rather than provide bypass steps.
2. **The realistic threat to all of these is physical access plus a weak unlock secret**, not
   Wi-Fi. So the useful output of this whole project for a device owner is a checklist:
   long alphanumeric passcode, FileVault/device encryption on, USB-accessory lock on iOS,
   and never store the Wi-Fi password as the unlock code.

### 12.3 Why the hardware-free design wins again

Because §7's synthesized-hash approach needs **no monitor mode anywhere**, the audit itself
runs on macOS, Windows, and (in principle) Android — only the optional *capture* step needs
Linux plus an adapter. Choosing hardware-free made the tool portable across every platform in
the question except iPhone/iPad, which cannot run third-party radios at all.

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

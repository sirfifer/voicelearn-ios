# Curriculum Sources: Foreign Language Availability Analysis

> **Generated:** 2026-01-02
> **Purpose:** Analyze non-English curriculum availability across identified sources to inform language expansion strategy

---

## Executive Summary

This analysis examines all curriculum sources currently identified for UnaMentis to determine their foreign language (non-English) content availability. The goal is to identify which languages have the richest available curriculum from reputable sources, enabling strategic decisions about which languages to prioritize for app localization.

**Key Findings:**
- **Spanish** has the broadest coverage across sources (9 of 11 major sources)
- **NPTEL** offers exceptional coverage in 11 Indian regional languages with rigorous quality control
- **OpenStax** provides professionally translated textbooks in 5 languages
- **Khan Academy** has the most extensive multilingual infrastructure (24+ full sites)
- Most university-level OER sources are English-only (Stanford SEE, Saylor, BCcampus)

---

## Source-by-Source Analysis

### Tier 1: Implemented Sources (Currently in App)

#### 1. MIT OpenCourseWare

| Metric | Value |
|--------|-------|
| **Implementation Status** | Fully Implemented |
| **English Catalog** | 2,500+ courses |
| **Translated Languages** | 10+ languages |
| **Quality Confidence** | Medium-High |

**Languages Available:**
- **Spanish** - Via Universia partnership (Spanish/Latin American universities consortium)
- **Portuguese** - Via Universia partnership
- **Traditional Chinese** - Via OOPS (volunteer organization)
- **Persian** - Via Shahid Beheshti University
- **Turkish** - Via Turkish Academy of Sciences
- **Korean** - Via SNOW
- Also reported: French, German, Vietnamese, Ukrainian

**Course Counts:** Not publicly quantified per language. Translations are distributed across partner sites, not centrally cataloged.

**Quality Indicators:**
- Official university/academic partnerships (not just volunteer translations)
- Universia represents 800+ colleges in Spain/Portugal/Latin America
- CC BY-NC-SA license ensures derivatives can be tracked
- Partner organizations have academic credibility

**Concerns:**
- Translations distributed across partner sites; no unified catalog
- Coverage varies significantly by language
- Some translations may be incomplete

**Sources:** [MIT Translated Courses](https://opencw.aprende.org/courses/translated-courses/), [MIT Open Learning](https://openlearning.mit.edu/)

---

#### 2. CK-12 FlexBooks

| Metric | Value |
|--------|-------|
| **Implementation Status** | Fully Implemented |
| **English Catalog** | 100+ K-12 FlexBooks |
| **Translated Languages** | 2 (manually translated) |
| **Quality Confidence** | High |

**Languages Available:**
- **Spanish** - Manual translations by CK-12 (not machine translation)
- **Hindi** - Some FlexBooks available

**Simulations (Interactive):**
- Korean
- German
- Chinese

**Quality Indicators:**
- **Manual translations**, not machine-generated
- Created by educational professionals
- Content specifically adapted for K-12 learners

**Course Counts by Language (Approximate):**
| Language | Content Type | Availability |
|----------|--------------|--------------|
| Spanish | FlexBooks | Multiple subjects, emphasis on math/science |
| Hindi | FlexBooks | Limited selection |
| Korean | Simulations only | Interactive SIMs |
| German | Simulations only | Interactive SIMs |
| Chinese | Simulations only | Interactive SIMs |

**Concerns:**
- Proprietary platform requiring partnership for API access
- Spanish coverage not comprehensive across all subjects

**Sources:** [CK-12 FlexBooks](https://www.ck12.org/fbbrowse/), [CK-12 Translation Help](https://help.ck12.org/hc/en-us/articles/204655064)

---

#### 3. MERLOT

| Metric | Value |
|--------|-------|
| **Implementation Status** | Fully Implemented |
| **English Catalog** | 100,000+ learning resources |
| **Translated Languages** | Aggregator (varies by resource) |
| **Quality Confidence** | Variable (peer-reviewed ratings) |

**Languages Available:**
MERLOT is an aggregator, not a content creator. Language availability varies by individual resource. Their World Languages Collection includes OER in:
- Spanish
- Chinese
- Arabic
- Portuguese
- Farsi
- Tamil
- Khmer
- Many less-commonly-taught languages

**Key Resource: COERLL**
The Center for Open Educational Resources & Language Learning (COERLL), accessible via MERLOT, offers resources in **23 languages** for language learning.

**Quality Indicators:**
- Peer-reviewed quality ratings
- Academic community curation since 1997
- CC license validation (blocks ND licenses)

**Concerns:**
- As an aggregator, quality varies widely
- Language coverage depends on contributed resources
- Not a source of translated curriculum, rather language learning resources

**Sources:** [MERLOT World Languages](https://www.merlot.org/merlot/WorldLanguages.htm), [MERLOT Wikipedia](https://en.wikipedia.org/wiki/MERLOT)

---

#### 4. EngageNY Mathematics

| Metric | Value |
|--------|-------|
| **Implementation Status** | Fully Implemented |
| **English Catalog** | PreK-12 Complete Math Curriculum |
| **Translated Languages** | 5 (initiative ongoing when discontinued) |
| **Quality Confidence** | Medium |

**Languages Available (In Progress at Discontinuation):**
- **Spanish** - Available via Internet Archive
- **Chinese (Simplified)** - Partial
- **Chinese (Traditional)** - Partial
- **Arabic** - Partial
- **Bengali** - Partial
- **Haitian Creole** - Partial

**Quality Indicators:**
- Official NYSED (NY State Education Department) initiative
- Standards-aligned to Common Core
- Translations done by education professionals

**Concerns:**
- NYSED discontinued support in July 2022
- Not all resources were completely translated
- Teachers advised to QC materials before use
- Archive only; no ongoing updates

**Sources:** [NYSED Translated Modules](https://www.engageny.org/resource/translated-modules), [EngageNY Spanish Archive](https://archive.org/details/EngageNY-mathematics-spanish)

---

#### 5. Core Knowledge Foundation

| Metric | Value |
|--------|-------|
| **Implementation Status** | Fully Implemented |
| **English Catalog** | K-8 comprehensive curriculum |
| **Translated Languages** | 1 (Spanish) |
| **Quality Confidence** | High |

**Languages Available:**
- **Spanish** - Select CKHG (History & Geography) titles free download
  - *Los Nativos Americanos y la Expansión Hacia el Oeste*
  - *La Formación de los Estados Unidos: Inmigración, Industrialización y Reforma*
  - Additional titles via Fathom Reads subscription

**Related Program: Amplify Caminos**
- K-5 Spanish Language Arts curriculum
- **Not a translation** of English CKLA; authentic Spanish curriculum
- Designed for biliteracy development
- Aligned with Core Knowledge Sequence

**Quality Indicators:**
- Created specifically for Spanish literacy (not translated)
- Aligned with established Core Knowledge Sequence
- Used in dual-language and immersion programs

**Concerns:**
- Limited free Spanish titles
- Full catalog requires Fathom Reads subscription
- Amplify Caminos is separate commercial product

**Sources:** [Core Knowledge Spanish CKHG](https://www.coreknowledge.org/blog/new-spanish-translation-ckhg/), [Amplify Caminos](https://amplify.com/programs/amplify-caminos/)

---

### Tier 2: Specification-Ready Sources

#### 6. Fast.ai

| Metric | Value |
|--------|-------|
| **Implementation Status** | Specification Ready |
| **English Catalog** | 4 complete AI/ML courses |
| **Translated Languages** | 2 (via captions) |
| **Quality Confidence** | Medium |

**Languages Available:**
- **Chinese (Simplified)** - Video captions/subtitles
- **Spanish** - Video captions/subtitles

**Quality Indicators:**
- Captions created by volunteers but reviewed
- Can be toggled via CC button in video player

**Concerns:**
- Only video captions, not full course material translation
- Jupyter notebooks and code remain in English

**Sources:** [Fast.ai Courses](https://course.fast.ai/)

---

#### 7. Stanford SEE (Stanford Engineering Everywhere)

| Metric | Value |
|--------|-------|
| **Implementation Status** | Specification Ready |
| **English Catalog** | 10 complete engineering courses |
| **Translated Languages** | 0 officially |
| **Quality Confidence** | N/A |

**Languages Available:**
- None found

**Quality Indicators:**
- CC BY-NC-SA license permits community translations
- No official translation partnerships identified

**Concerns:**
- English only
- Pilot program ended; no new courses being added

**Sources:** [Stanford SEE](https://see.stanford.edu/), [Stanford SEE FAQ](https://see.stanford.edu/UsingSEE)

---

### Tier 3: Planned Sources

#### 8. OpenStax

| Metric | Value |
|--------|-------|
| **Implementation Status** | Planned |
| **English Catalog** | 60+ peer-reviewed textbooks |
| **Translated Languages** | 5 |
| **Quality Confidence** | Very High |

**Languages Available with Dedicated Programs:**
| Language | Textbooks | Partner Organization |
|----------|-----------|---------------------|
| **Spanish** | University Physics (Física Universitaria, 3 vols), others | OpenStax direct |
| **Polish** | Select titles | OpenStax Polska / Katalyst Education |
| **Arabic** | Select titles | OpenStax partnerships |
| **Chinese (Simplified)** | Select titles | OpenStax partnerships |
| **English** | 60+ complete textbooks | Rice University |

**Quality Indicators:**
- **Professional translations** (not volunteer/machine)
- Peer-reviewed like English originals
- OpenStax Polska is formal partnership with academic institutions
- Print versions available (Spanish Physics in paperback)
- $2.9B saved by students suggests massive adoption

**Concerns:**
- Not all 60+ English books are translated
- Need to verify exact titles available per language

**Sources:** [OpenStax](https://openstax.org), [OpenStax Wikipedia](https://en.wikipedia.org/wiki/OpenStax), [OpenStax Polska](https://katalysteducation.org/project/openstax)

---

#### 9. Saylor Academy

| Metric | Value |
|--------|-------|
| **Implementation Status** | Planned |
| **English Catalog** | 150+ college-level courses |
| **Translated Languages** | 0 |
| **Quality Confidence** | N/A |

**Languages Available:**
- None

Platform supports multiple interface languages via Moodle, but all course content is English-only. Recommends browser translation plugins.

**Concerns:**
- Entirely English-only content
- Browser translation is not curriculum-quality

**Sources:** [Saylor Languages FAQ](https://support.saylor.org/hc/en-us/articles/224742307)

---

#### 10. NPTEL (National Programme on Technology Enhanced Learning)

| Metric | Value |
|--------|-------|
| **Implementation Status** | Planned |
| **English Catalog** | 700+ courses (22 disciplines) |
| **Translated Languages** | 11 |
| **Quality Confidence** | Very High |

**Languages Available:**
| Language | Courses | Translators | QC Reviewers | E-books | Audio Hours |
|----------|---------|-------------|--------------|---------|-------------|
| **Hindi** | 207+ | 1,029 | 139 | 199 | 1,200 |
| **Tamil** | 174+ | 682 | 51 | 159 | 906 |
| **Bengali** | Available | Active team | Active | Yes | Yes |
| **Telugu** | Available | Active team | Active | Yes | Yes |
| **Kannada** | Available | Active team | Active | Yes | Yes |
| **Malayalam** | Available | Active team | Active | Yes | Yes |
| **Marathi** | Available | Active team | Active | Yes | Yes |
| **Gujarati** | Available | Active team | Active | Yes | Yes |
| **Odia** | Available | Active team | Active | Yes | Yes |
| **Punjabi** | Available | Active team | Active | Yes | Yes |
| **Assamese** | Available | Active team | Active | Yes | Yes |

**Total:** 20,000+ hours of translated content, 980 translated books

**Quality Indicators:**
- **Rigorous two-level review process**
- Dedicated QC teams per language (139 QC reviewers for Hindi alone)
- Paid honorarium for reviewers (incentivizes quality)
- Technical terminology retained in English (transliterated) for accuracy
- Multiple formats: PDF, e-books, subtitles, scrolling text, audio
- Government-funded initiative (IIT Madras / Ministry of Education)

**This is the highest-quality translation effort identified in this research.**

**Sources:** [NPTEL Translation](https://nptel.ac.in/translation), [PIB Press Release](https://www.pib.gov.in/PressReleasePage.aspx?PRID=2017582), [NPTEL Stories](https://stories.nptel.ac.in/)

---

#### 11. OpenLearn (Open University UK)

| Metric | Value |
|--------|-------|
| **Implementation Status** | Planned |
| **English Catalog** | 1,000+ free courses |
| **Translated Languages** | 0 (offers language learning courses) |
| **Quality Confidence** | N/A |

**Languages Available:**
- None (English-only platform)

OpenLearn offers courses *for learning* languages (Spanish, French, German, Italian, Chinese, Welsh, Gaelic, Arabic) but the courses themselves are in English.

**Sources:** [OpenLearn Languages](https://www.open.edu/openlearn/languages)

---

#### 12. BCcampus OpenEd

| Metric | Value |
|--------|-------|
| **Implementation Status** | Planned |
| **English Catalog** | 400+ open textbooks |
| **Translated Languages** | 0 |
| **Quality Confidence** | N/A |

**Languages Available:**
- None found

Canadian OER initiative, English-only.

---

#### 13. LibreTexts

| Metric | Value |
|--------|-------|
| **Implementation Status** | Planned |
| **English Catalog** | Thousands of textbooks (12 libraries) |
| **Translated Languages** | 0 (offers language learning resources) |
| **Quality Confidence** | N/A |

**Languages Available:**
- None for general subjects

LibreTexts has language *learning* resources (Spanish, French, Chinese, German, Arabic, Hindi) in their Humanities library, but textbooks on other subjects (Chemistry, Physics, Math) are English-only.

**Sources:** [LibreTexts Languages](https://human.libretexts.org/Bookshelves/Languages)

---

### Bonus: Khan Academy (Not in Current Sources, but Reference)

| Metric | Value |
|--------|-------|
| **Implementation Status** | Not planned (proprietary) |
| **English Catalog** | Full K-14 curriculum |
| **Translated Languages** | 24+ full sites |
| **Quality Confidence** | High (volunteer + foundation support) |

**Full Localized Sites (Large Translation Coverage):**
Armenian, Azerbaijani, Bangla, Bulgarian, Czech, Danish, Dutch, French, Georgian, German, Hungarian, Korean, Marathi, Norwegian, Polish, Portuguese (Brazilian), Portuguese (European), Punjabi, Serbian, Spanish, Turkish, Vietnamese, Chinese (Simplified)

**Quality-Tested for Khanmigo AI:** English, Hindi, Spanish, Portuguese

**Quality Indicators:**
- Volunteer-driven with Language Advocates as team leads
- Some teams receive foundation/sponsor funding
- Uses Crowdin translation platform
- Extensive review process with coordinator oversight

**Concerns:**
- Proprietary platform (not OER)
- Volunteer quality varies
- Currently not onboarding new language teams due to resource constraints

**Sources:** [Khan Academy Languages](https://support.khanacademy.org/hc/en-us/articles/226457308), [Khan Academy Translators](https://support.khanacademy.org/hc/en-us/categories/200186020)

---

## Language Coverage Summary Matrix

| Language | MIT OCW | CK-12 | EngageNY | Core K | Fast.ai | OpenStax | NPTEL | Total Sources |
|----------|---------|-------|----------|--------|---------|----------|-------|---------------|
| **Spanish** | Yes | Yes | Yes | Yes | Yes | Yes | No | 6 |
| **Portuguese** | Yes | No | No | No | No | No | No | 1 |
| **Chinese (Simp)** | Yes | SIMs | Yes | No | Yes | Yes | No | 4 |
| **Chinese (Trad)** | Yes | No | Yes | No | No | No | No | 2 |
| **Hindi** | No | Yes | No | No | No | No | Yes | 2 |
| **Tamil** | No | No | No | No | No | No | Yes | 1 |
| **Arabic** | No | No | Yes | No | No | Yes | No | 2 |
| **Polish** | No | No | No | No | No | Yes | No | 1 |
| **Korean** | Yes | SIMs | No | No | No | No | No | 1+ |
| **Turkish** | Yes | No | No | No | No | No | No | 1 |
| **Persian** | Yes | No | No | No | No | No | No | 1 |
| **German** | Yes | SIMs | No | No | No | No | No | 1+ |
| **Bengali** | No | No | Yes | No | No | No | Yes | 2 |
| **French** | Yes | No | No | No | No | No | No | 1 |

---

## Quality Assessment Framework

### Quality Tier Definitions

| Tier | Definition | Examples |
|------|------------|----------|
| **Tier 1: Professional** | Dedicated translation teams, paid QC reviewers, institutional backing | NPTEL, OpenStax Polska |
| **Tier 2: Curated Volunteer** | Organized volunteer teams with review processes | Khan Academy, MIT OCW partnerships |
| **Tier 3: Basic Translation** | Machine-assisted or minimal QC | Saylor (browser plugin), some MIT community translations |
| **Tier 4: None** | English only | Stanford SEE, BCcampus, LibreTexts |

### Source Quality Ratings

| Source | Quality Tier | Evidence |
|--------|--------------|----------|
| **NPTEL** | Tier 1 | 139+ QC reviewers for Hindi alone; paid honorarium; two-level review; government funding |
| **OpenStax** | Tier 1 | Formal partnerships (Polska); print publication; peer review |
| **CK-12** | Tier 1-2 | Manual (not machine) translations; educational professionals |
| **Core Knowledge** | Tier 1-2 | Purpose-built Spanish curriculum (Amplify Caminos) |
| **Khan Academy** | Tier 2 | Language Advocates; Crowdin platform; foundation support |
| **MIT OCW** | Tier 2 | Academic partnership organizations; but distributed/incomplete |
| **EngageNY** | Tier 2-3 | Official NYSED but incomplete; archived without updates |
| **Fast.ai** | Tier 3 | Volunteer captions only |
| **Saylor** | Tier 4 | Browser translation recommended |
| **Stanford SEE** | Tier 4 | No translations |
| **OpenLearn** | Tier 4 | No translations (language learning courses only) |
| **BCcampus** | Tier 4 | No translations |
| **LibreTexts** | Tier 4 | No translations |

---

## Strategic Recommendations

### Languages to Prioritize (Based on Curriculum Availability)

| Priority | Language | Rationale |
|----------|----------|-----------|
| **1** | **Spanish** | Broadest coverage (6 sources), highest quality (OpenStax, CK-12), K-12 through university |
| **2** | **Hindi** | NPTEL exceptional quality (207+ courses, rigorous QC), CK-12 FlexBooks, growing market |
| **3** | **Chinese (Simplified)** | 4 sources, OpenStax & MIT OCW quality, large market |
| **4** | **Portuguese (Brazilian)** | MIT OCW via Universia, Khan Academy full site (not in our sources but reference) |
| **5** | **Arabic** | OpenStax & EngageNY coverage, growing demand |

### Regional Language Opportunities

**Indian Market (via NPTEL):**
If targeting India, NPTEL provides exceptional university-level STEM content in 11 languages. The quality control process (1,000+ translators, 100+ QC reviewers per major language) exceeds any other source identified.

Recommended NPTEL languages by course count:
1. Hindi (207+ courses)
2. Tamil (174+ courses)
3. Bengali, Telugu, Kannada, Malayalam (active programs)

### Implementation Path

**Phase 1: Spanish**
- Highest curriculum coverage
- OpenStax for university STEM
- CK-12 for K-12
- Core Knowledge for K-8 humanities
- EngageNY archive for math

**Phase 2: Assess Market Demand**
- Hindi vs Chinese based on user demographics
- NPTEL integration if targeting Indian market
- OpenStax Chinese/Arabic for global expansion

**Phase 3: Regional Expansion**
- Portuguese via MIT OCW partnerships
- Indian regional languages via NPTEL

---

## Gaps and Unknowns

### Data Not Found
1. Exact course counts per language for MIT OCW translations
2. Complete list of OpenStax titles in each translated language
3. CK-12 Spanish FlexBook complete catalog (API blocked)
4. MERLOT breakdown of multilingual resources by subject/level

### Quality Questions
1. Are MIT OCW partner translations kept current with English updates?
2. What percentage of EngageNY translations were completed before discontinuation?
3. How do OpenStax Polska textbooks compare to English originals in coverage?

### Sources Not Researched
- OER Commons (aggregator, variable quality)
- African Virtual University
- Japan OCW Consortium

---

## Appendix: Source Links

### Implemented Sources
- [MIT OCW Translations](https://opencw.aprende.org/courses/translated-courses/)
- [CK-12 FlexBooks](https://www.ck12.org/)
- [MERLOT World Languages](https://www.merlot.org/merlot/WorldLanguages.htm)
- [EngageNY Spanish Archive](https://archive.org/details/EngageNY-mathematics-spanish)
- [Core Knowledge Spanish CKHG](https://www.coreknowledge.org/blog/new-spanish-translation-ckhg/)

### Planned Sources
- [NPTEL Translation Portal](https://nptel.ac.in/translation)
- [OpenStax](https://openstax.org)
- [OpenStax Polska](https://katalysteducation.org/project/openstax)
- [Saylor Academy](https://www.saylor.org/)
- [Fast.ai](https://course.fast.ai/)
- [Stanford SEE](https://see.stanford.edu/)
- [OpenLearn](https://www.open.edu/openlearn/)
- [LibreTexts Languages](https://human.libretexts.org/Bookshelves/Languages)

### Quality Process Documentation
- [Khan Academy Translation Quality](https://support.khanacademy.org/hc/en-us/articles/226319087)
- [NPTEL QC Process](https://nptel.ac.in/translation)
